# Menu Title: Nuke Selected Item Comments
# Needs Case: true
# Needs Selected Items: true

# Blanks out comments on selected items which have comments
# Closes workbench tabs before and opens a fresh one after

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

if $current_selected_items.size < 1
	CommonDialogs.showError("This script requires items be selected before running it.")
	exit 1
end

if !CommonDialogs.getConfirmation("This script needs to close all workbench tabs.  Continue?","Close All Tabs?")
	puts "User did not allow script to close all workbench tabs."
	exit 1
else
	$window.closeAllTabs
end

ProgressDialog.forBlock do |pd|
	pd.setTitle("Comment Nuker")
	pd.setAbortButtonVisible(true)

	pd.logMessage("Closing all workbench tabs...")
	pd.logMessage("Selected Items: #{$current_selected_items.size}")
	pd.logMessage("Filtering selection to only items which have a comment...")
	items_with_comment = $current_case.search("has-comment:1")
	items_to_process = $utilities.getItemUtility.intersection($current_selected_items,items_with_comment)
	pd.logMessage("Selected Items with Comment: #{items_to_process.size}")
	last_progress = Time.now
	items_to_process.each_with_index do |item,index|
		break if pd.abortWasRequested
		item.setComment(nil)
		if (Time.now - last_progress) > 1 || index+1 == items_to_process.size
			pd.setMainStatus("#{index+1}/#{items_to_process.size}")
			pd.setMainProgress(index+1,items_to_process.size)
			last_progress = Time.now
		end
	end

	if pd.abortWasRequested
		pd.logMessage("User Aborted")
	else
		pd.setCompleted
	end

	$window.openTab("workbench",{:search=>""})
end