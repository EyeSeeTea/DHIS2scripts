# A source metadata export 
old_md <- fromJSON('~/../Desktop/md.json')

# Get what it should be
setDHIS2_credentials('who')
md <- getDHIS2_detailedExport(program_id, 'programs', usr, pwd, url, F)


# Loop through each attribute in the old_md and check if the 
# id values exist in md (what it should be).  If it is, 
# return nothing, else return the id for deletion

for_delete <- lapply(names(old_md[-1]), function(x) {
  if (length(old_md[[x]]) > 0) {
    lapply(old_md[[x]], function(y) {
      if (!(y$id %in% sapply(md[[x]], function (z) z$id))) {
        return(y)
      }
    })
}})

# Loop removes names on the list, add them back
names(for_delete) <- names(old_md[-1])


# Make the final json with a list of ids to remove
for (i in names(for_delete)) {
  # find the not null elements in the for_delete object. this returns 
  # indicies into removal
  removal <- for_delete[[i]][which(!sapply(for_delete[[i]], is.null))]
  
  if (length(removal) > 0) {
    # if found, keep the indices we should remove
    for_delete[[i]] <- removal
  }
  else {
    # otherwise, no need to keep that attribute (dataElements, indicators, etc)
    for_delete[i] = NULL # this effectively drops it
  }
}

# save it out
saveDHIS2_metadataExport(for_delete, 'ETA_for_deletion.json')
