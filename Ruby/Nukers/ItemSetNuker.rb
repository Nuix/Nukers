# encoding: UTF-8
# Menu Title: Item Set Nuker
# Needs Case: true

script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.ProcessingStatusDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

item_set_choices = $current_case.getAllItemSets.sort_by{|p|p.getName}.map{|p|Choice.new(p.getName)}

dialog = TabbedCustomDialog.new("Item Set Nuker")

main_tab = dialog.addTab("settings_tab","Settings")
main_tab.appendChoiceTable("item_sets","Item Sets to Remove",item_set_choices)

# Validate user settings
dialog.validateBeforeClosing do |values|
	# Make sure user selected at least one item set
	if values["item_sets"].size < 1
		CommonDialogs.showWarning("You must check at least 1 item set.")
		next false
	end

	# Get user to confirm they are about to delete some item sets
	message = "You are about to remove #{values["item_sets"].size} item sets from the case, proceed?"
	title = "Proceed?"
	next CommonDialogs.getConfirmation(message,title)
end

# Display the actual dialog
dialog.display

# If user clicked ok and settings checked out, lets get to work
if dialog.getDialogResult == true
	# Pull out settings from dialog into handy variables
	values = dialog.toMap
	item_sets = values["item_sets"]

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Item Set Nuker")
		pd.setAbortButtonVisible(true)

		# Echo progress dialog messages to Nuix log
		pd.onMessageLogged do |message|
			puts message
		end

		# Log each item set we will be removing
		pd.logMessage("Item Sets being removed:")
		item_sets.each do |item_set|
			pd.logMessage("- #{item_set}")
		end

		# Iterate each item set user selected
		pd.setMainProgress(0,item_sets.size)
		item_sets.each_with_index do |item_set,item_set_index|
			# Break from iteration if user requested we abort
			break if pd.abortWasRequested

			pd.setMainStatusAndLogIt("Processing (#{item_set_index+1}/#{item_sets.size}): #{item_set}")
			pd.setMainProgress(item_set_index+1)

			# Delete this item set
			pd.setMainStatusAndLogIt("Deleting item set #{item_set}")
			item_set_object = $current_case.findItemSetByName(item_set)
			$current_case.deleteItemSet(item_set_object)
		end

		# Show we have finished
		if pd.abortWasRequested
			pd.setMainStatusAndLogIt("User Aborted")
		else
			pd.setCompleted
		end
	end
end