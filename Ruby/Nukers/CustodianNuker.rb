# encoding: UTF-8
# Menu Title: Custodian Nuker
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

# Method to escape certain characters which are legally allowed to be in a custodian's name
# but will cause issues in a query without first being escaped
def escape_custodian_for_search(custodian)
	return custodian.encode("utf-8")
		.gsub("\\","\\\\\\") #Escape \
		.gsub("?","\\?") #Escape ?
		.gsub("*","\\*") #Escape *
		.gsub("\"","\\\"") #Escape "
		.gsub("\u201C".encode("utf-8"),"\\\u201C".encode("utf-8")) #Escape left smart quote
		.gsub("\u201D".encode("utf-8"),"\\\u201D".encode("utf-8")) #Escape right smart quote
		.gsub("'","\\\\'") #Escape '
		.gsub("{","\\{")
		.gsub("}","\\}")
end

dialog = TabbedCustomDialog.new("Custodian Nuker")

all_custodians = $current_case.getAllCustodians.sort
custodian_choices = all_custodians.map{|c|Choice.new(c)}

if all_custodians.size < 1
	CommonDialogs.showInformation("No custodians are present in the current case.","Custodian Nuker")
	exit 1
end

main_tab = dialog.addTab("settings_tab","Settings")
main_tab.appendSpinner("batch_size","Removal Batch Size",1000,100,1_000_000,100)
main_tab.appendChoiceTable("custodians","Custodians to Remove",custodian_choices)

# Validate user settings
dialog.validateBeforeClosing do |values|
	# Make sure user selected at least one custodian
	if values["custodians"].size < 1
		CommonDialogs.showWarning("You must check at least 1 custodian.")
		next false
	end

	# Get user to confirm that they are about to remove some custodians
	message = "You are about to remove #{values["custodians"].size} custodians from all items and the case, proceed?"
	title = "Proceed?"
	next CommonDialogs.getConfirmation(message,title)
end

# Display the actual dialog
dialog.display

# If user clicked ok and settings checked out, lets get to work
if dialog.getDialogResult == true
	# Pull out settings from dialog into handy variables
	values = dialog.toMap
	batch_size = values["batch_size"]
	custodians = values["custodians"]

	# We'll be using this to remove custodians from items
	annotater = $utilities.getBulkAnnotater

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Custodian Nuker")
		pd.setAbortButtonVisible(true)

		# Echo progress dialog messages to Nuix log
		pd.onMessageLogged do |message|
			puts message
		end

		pd.logMessage("Custodians being removed:")
		custodians.each do |custodian|
			pd.logMessage("- #{custodian}")
		end

		pd.setMainProgress(0,custodians.size)
		custodians.each_with_index do |custodian,custodian_index|
			break if pd.abortWasRequested

			pd.logMessage("#{custodian_index+1}/#{custodians.size}: Custodian '#{custodian}'")
			pd.setMainProgress(custodian_index+1)
			pd.logMessage("Obtaining items assigned to custodian...")
			custodian_items = $current_case.search("custodian:\"#{escape_custodian_for_search(custodian)}\"")
			pd.logMessage("Obtained #{custodian_items.size} items")
			
			custodian_items.each_slice(batch_size) do |slice_items|
				pd.logMessage("Removing custodian from batch of #{slice_items.size} items...")
				pd.setSubProgress(0,custodian_items.size)
				annotater.unassignCustodian(custodian_items) do |info|
					pd.setSubProgress(info.getStageCount)
				end
			end

			pd.logMessage("Deleting custodian from the case...")
			$current_case.deleteCustodian(custodian)
		end

		# Show we have finished
		if pd.abortWasRequested
			pd.setMainStatusAndLogIt("User Aborted")
		else
			pd.setCompleted
		end
	end
end