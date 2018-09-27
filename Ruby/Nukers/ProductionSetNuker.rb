# encoding: UTF-8
# Menu Title: Production Set Nuker
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

production_set_choices = $current_case.getProductionSets.sort_by{|p|p.getName}.map{|p|Choice.new(p.getName)}

dialog = TabbedCustomDialog.new("Production Set Nuker")

main_tab = dialog.addTab("settings_tab","Settings")
main_tab.appendChoiceTable("production_sets","Production Sets to Remove",production_set_choices)

# Validate user settings
dialog.validateBeforeClosing do |values|
	if values["production_sets"].size < 1
		CommonDialogs.showWarning("You must check at least 1 production set.")
		next false
	end

	message = "You are about to remove #{values["production_sets"].size} production sets from the case, proceed?"
	title = "Proceed?"
	next CommonDialogs.getConfirmation(message,title)
end

# Display the actual dialog
dialog.display

# If user clicked ok and settings checked out, lets get to work
if dialog.getDialogResult == true
	# Pull out settings from dialog into handy variables
	values = dialog.toMap
	production_sets = values["production_sets"]

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Production Set Nuker")
		pd.setAbortButtonVisible(true)

		# Echo progress dialog messages to Nuix log
		pd.onMessageLogged do |message|
			puts message
		end

		pd.logMessage("Production Sets being removed:")
		production_sets.each do |production_set|
			pd.logMessage("- #{production_set}")
		end

		pd.setMainProgress(0,production_sets.size)
		production_sets.each_with_index do |production_set,production_set_index|
			# Break from iteration if user requested we abort
			break if pd.abortWasRequested

			pd.setMainStatusAndLogIt("Processing (#{production_set_index+1}/#{production_sets.size}): #{production_set}")
			pd.setMainProgress(production_set_index+1)

			pd.setMainStatusAndLogIt("Deleting production set #{production_set}")
			$current_case.findProductionSetByName(production_set).delete
		end

		# Show we have finished
		if pd.abortWasRequested
			pd.setMainStatusAndLogIt("User Aborted")
		else
			pd.setCompleted
		end
	end
end