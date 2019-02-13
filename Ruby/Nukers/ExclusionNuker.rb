# encoding: UTF-8
# Menu Title: Exclusion Nuker
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

all_exclusions = $current_case.getAllExclusions.sort
exclusion_choices = all_exclusions.map{|f|Choice.new(f)}

dialog = TabbedCustomDialog.new("Exclusion Nuker")

main_tab = dialog.addTab("settings_tab","Settings")
main_tab.appendChoiceTable("exclusions","Exclusions to Remove",exclusion_choices)

# Validate user settings
dialog.validateBeforeClosing do |values|
	if values["exclusions"].size < 1
		CommonDialogs.showWarning("You must check at least 1 exclusion.")
		next false
	end

	message = "You are about to remove #{values["exclusions"].size} exclusions from all items in the case, proceed?"
	title = "Proceed?"
	next CommonDialogs.getConfirmation(message,title)
end

# Display the actual dialog
dialog.display

# If user clicked ok and settings checked out, lets get to work
if dialog.getDialogResult == true
	# Pull out settings from dialog into handy variables
	values = dialog.toMap
	exclusions = values["exclusions"]

	# We'll be using this to remove tags
	annotater = $utilities.getBulkAnnotater

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Exclusion Nuker")
		pd.setAbortButtonVisible(true)

		# Echo progress dialog messages to Nuix log
		pd.onMessageLogged do |message|
			puts message
		end

		pd.logMessage("Exclusions being removed:")
		exclusions.each do |exclusion|
			pd.logMessage("- #{exclusion}")
		end

		pd.setMainProgress(0,exclusions.size)
		exclusions.each_with_index do |exclusion,exclusion_index|
			# Break from iteration if user requested we abort
			break if pd.abortWasRequested

			pd.setMainStatusAndLogIt("Processing (#{exclusion_index+1}/#{exclusions.size}): #{exclusion}")
			pd.setMainProgress(exclusion_index+1)

			query = "exclusion:\"#{exclusion}\""
			items = $current_case.searchUnsorted(query)
			pd.setSubStatusAndLogIt("Removing exclusion from #{items.size} items...")
			annotater.include(items)
		end

		# Show we have finished
		if pd.abortWasRequested
			pd.setMainStatusAndLogIt("User Aborted")
		else
			pd.setCompleted
		end
	end
end