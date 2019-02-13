# encoding: UTF-8
# Menu Title: Custom Metadata Nuker
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

all_fields = $current_case.getCustomMetadataFields.sort
field_choices = all_fields.map{|f|Choice.new(f)}
has_selected_items = $current_selected_items.nil? == false && $current_selected_items.size > 0

dialog = TabbedCustomDialog.new("Custom Metadata Nuker")

main_tab = dialog.addTab("settings_tab","Settings")

# If items were selected when the script was started up, we give the user the option to run this against only
# those selected items.  If no items were selected, then they only have the choice to run against all items.
if has_selected_items
	main_tab.appendRadioButton("selected_items","Remove from #{$current_selected_items.size} selected items","selection_group",true)
	main_tab.appendRadioButton("all_items","Remove from all #{$current_case.count("")} items in the case","selection_group",false)
else
	main_tab.appendRadioButton("all_items","All #{$current_case.count("")} items in the case","selection_group",true)
end

main_tab.appendChoiceTable("fields","Fields to Remove",field_choices)

# Validate user settings
dialog.validateBeforeClosing do |values|
	# Make sure at least one field has been selected by the user
	if values["fields"].size < 1
		CommonDialogs.showWarning("You must check at least 1 custom metadata field.")
		next false
	end

	# Since this script performs a removal of custom metadata, lets warn the user and get them to confirm
	# that they understand what they are about to do.
	message = nil
	if values["all_items"]
		message = "You are about to remove #{values["fields"].size} custom metadata fields from all items in the case, proceed?"
	else
		message = "You are about to remove #{values["fields"].size} custom metadata fields from #{$current_selected_items.size} selected items in the case, proceed?"
	end
	title = "Proceed?"
	next CommonDialogs.getConfirmation(message,title)
end

# Display the actual dialog
dialog.display

# If user clicked ok and settings checked out, lets get to work
if dialog.getDialogResult == true
	# Pull out settings from dialog into handy variables
	values = dialog.toMap
	all_items = values["all_items"]
	fields = values["fields"]

	# We'll be using this to remove fields
	annotater = $utilities.getBulkAnnotater

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Custom Metadata Nuker")
		pd.setAbortButtonVisible(true)

		# Echo progress dialog messages to Nuix log
		pd.onMessageLogged do |message|
			puts message
		end

		# Log which fields the user has selected for removal
		pd.logMessage("Fields being removed:")
		fields.each do |field|
			pd.logMessage("- #{field}")
		end

		pd.setMainProgress(0,fields.size)

		# Iterate each custom metadata field the user selected
		fields.each_with_index do |field,field_index|
			# Break from iteration if user requested we abort
			break if pd.abortWasRequested

			pd.setMainStatusAndLogIt("Processing (#{field_index+1}/#{fields.size}): #{field}")
			pd.setMainProgress(field_index+1)

			# If were removing selected custom metadata fields from all items, we can just search
			# for those items which have the field we are currently removing, potentially reducing
			# the items we send to removeCustomMetadata method.  If not we just pass along the
			# entire selected items collection.
			items = nil
			if all_items
				# Lets search for items which actually have this field
				field = field.gsub(":","")
				query = "custom-metadata:\"#{field}\":\"*\""
				items = $current_case.searchUnsorted(query)
			else
				items = $current_selected_items
			end

			# Remove the currently field from items
			pd.setSubStatusAndLogIt("Removing field from #{items.size} items...")
			annotater.removeCustomMetadata(field,items) do |info|
				pd.setSubProgress(info.getStageCount,items.size)
			end
		end

		# Show we have finished
		if pd.abortWasRequested
			pd.setMainStatusAndLogIt("User Aborted")
		else
			pd.setCompleted
		end
	end
end