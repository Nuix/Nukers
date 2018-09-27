# encoding: UTF-8
# Menu Title: Tag Nuker
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

# Method to escape certain characters which are legally allowed to be in a tag's name
# but will cause issues in a query without first being escaped
def escape_tag_for_search(tag)
	return tag.encode("utf-8")
		.gsub("\\","\\\\\\") #Escape \
		.gsub("?","\\?") #Escape ?
		.gsub("*","\\*") #Escape *
		.gsub("\"","\\\"") #Escape "
		.gsub("\u201C".encode("utf-8"),"\\\u201C".encode("utf-8")) #Escape left smart quote
		.gsub("\u201D".encode("utf-8"),"\\\u201D".encode("utf-8")) #Escape right smart quote
		.gsub("'","\\\\'") #Escape '
end

dialog = TabbedCustomDialog.new("Tag Nuker")

all_tags = $current_case.getAllTags.sort
tag_choices = all_tags.map{|t|Choice.new(t)}

main_tab = dialog.addTab("settings_tab","Settings")
main_tab.appendSpinner("batch_size","Removal Batch Size",1000,100,1_000_000,100)
main_tab.appendChoiceTable("tags","Tags to Remove",tag_choices)

# Validate user settings
dialog.validateBeforeClosing do |values|
	if values["tags"].size < 1
		CommonDialogs.showWarning("You must check at least 1 tag.")
		next false
	end

	# Checking parent tags implicitly means we are also removing their child tags
	# so we will determine what child tags that may be and note this to user
	implied_tags = []
	all_tags.each do |tag|
		values["tags"].each do |selected_tag|
			if tag != selected_tag && tag.start_with?(selected_tag+"|")
				implied_tags << tag
			end
		end
	end
	implied_tags.uniq!

	message = "You are about to remove #{values["tags"].size} tags (and #{implied_tags.size} nested tags) from all items and the case, proceed?"
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
	tags = values["tags"]

	# Checking parent tags implicitly means we are also removing their child tags
	# so we will determine what child tags that may be
	implied_tags = []
	all_tags.each do |tag|
		values["tags"].each do |selected_tag|
			if tag != selected_tag && tag.start_with?(selected_tag+"|")
				implied_tags << tag
			end
		end
	end
	implied_tags.uniq!

	# We will remove tags in reverse order, this is so that we remove
	# child tags before their "parent" tags, example:
	#
	# Reviewed
	# Reviewed|Confidential
	# Reviewed|Confidential|Special
	#
	# is processed in this order:
	#
	# Reviewed|Confidential|Special
	# Reviewed|Confidential
	# Reviewed
	tags = (implied_tags+tags).uniq.sort.reverse

	# We'll be using this to remove tags
	annotater = $utilities.getBulkAnnotater

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Tag Nuker")
		pd.setAbortButtonVisible(true)

		# Echo progress dialog messages to Nuix log
		pd.onMessageLogged do |message|
			puts message
		end

		pd.logMessage("Tags being removed:")
		tags.each do |tag|
			pd.logMessage("- #{tag}")
		end

		pd.setMainProgress(0,tags.size)
		tags.each_with_index do |tag,tag_index|
			# Break from iteration if user requested we abort
			break if pd.abortWasRequested

			pd.setMainStatusAndLogIt("Processing (#{tag_index+1}/#{tags.size}): #{tag}")
			pd.setMainProgress(tag_index+1)

			# Search for any items with this tag or child tags since we cannot remove a parent tag
			# that still has child tags
			pd.setSubStatus("Locating tagged items...")
			query = "tag:\"#{escape_tag_for_search(tag)}\" OR tag:\"#{escape_tag_for_search(tag)}|*\""
			pd.logMessage("Query: #{query}")
			items = $current_case.searchUnsorted(query)
			pd.logMessage("Located #{items.size} items with tag")

			# Begin removing this ta
			pd.setSubStatus("Removing tag from #{items.size} items...")
			total_untagged = 0
			items.each_slice(batch_size) do |slice_items|
				# Break from iteration if user requested we abort
				break if pd.abortWasRequested

				annotater.removeTag(tag,slice_items)
				total_untagged += slice_items.size
				pd.setSubStatus("Removing Tag: #{total_untagged}/#{items.size}")
			end

			# Only take this step if we don't have pending abort request
			if !pd.abortWasRequested
				pd.setSubStatusAndLogIt("Deleting tag from case...")
				$current_case.deleteTag(tag)
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