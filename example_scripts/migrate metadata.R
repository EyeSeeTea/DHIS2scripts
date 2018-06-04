# Migrate metadata script ------

program_id <- 'YGa3BmrwwiU'

setDHIS2_credentials('who', suffix='.who')
who_prog <- getDHIS2_detailedExport(program_id, 'programs', usr.who, pwd.who, url.who, F)
saveDHIS2_metadataExport(who_prog, sprintf('who_backup_%s.json',Sys.time() %>% as.character() %>% gsub('[-,:, ]', '', .)))

setDHIS2_credentials('epitech-dev')

prog_info <- getDHIS2_detailedExport(program_id, 'programs', usr, pwd, url, F)
saveDHIS2_metadataExport(prog_info, sprintf('epitech_backup_%s.json',Sys.time() %>% as.character() %>% gsub('[-,:, ]', '', .)))


# EpiTech server only has ETA program, otherwise pull all indicators and indicator groups that start with "ETA" -------------
indicators <- getDHIS2_Resource('indicators', usr, pwd, url, 'indicatorGroups')

md <- GET(sprintf("%smetadata?indicators=true&indicatorGroups=true", url), authenticate(usr, pwd), accept_json()) %>% content()  %>% removeDHIS2_userInfo()
prog_info <- getDHIS2_detailedExport(program_id, 'programs', usr, pwd, url, F)
# NOTE: this is a metadata dependency export for the program at /api/programs/ID/metadata.json

prog_info %<>% append(md[-1]) # R is 1 indexed, so 1 is the pull date


# Visualization/Analytics dependencies ----------------------
# Dashboard dependency exports will pull all of the necessary reports and charts/tables
# Otherwise pull any chart/reportTable that starts with "ETA"
# NOTE: There is an extra dashboard called "-1. Extras" which are lightly used.  The Injury Severity report
# contains links for more detail to a few of the tables.  We had something similar for the 
# Patient Demographics table at first, but then removed them.  I've shared it with 
# Jordi and Ignacio. 

dashboards <- getDHIS2_Resource('dashboards', usr, pwd, url) # These are user specific
# Otherwise, do a dependency export for all of the known ETA dashboard ids, which is what 
# this does
charts_and_viz <- lapply(dashboards$id, function(x) {
  new_viz <- getDHIS2_detailedExport(x, 'dashboards', usr, pwd, url, F, usr.who, pwd.who, url.who)
  # r <- postDHIS2_metadataPackage(new_viz, usr.who, pwd.who, url.who,strategy = 'CREATE_AND_UPDATE')
  # content(r, 'text')
  if (x == 'E0PIAD48nHY') { # the -1. Extras dashboard, 
    # we don't care about actually adding the dashboard itself, just the tables and charts so they're available.
    new_viz[c('dashboards', 'dashboardItems')] = NULL
  }
  new_viz
})

# THey're currently separate arrays, stitch them into one here and remove any potential duplicates:
for (n in charts_and_viz) {
  for (i in names(n)) {
    if (!(i %in% names(prog_info))) {
      # in R, lists are like dictionaries with key/values. 
      # this creates a new key attribute to add to if we haven't seen it before. 
      prog_info[[i]] <- list() 
    }
    prog_info[[i]] %<>% append(n[[i]])
  }
}

ind_types <- getDHIS2_specificExport(unique(sapply(prog_info$indicators, function(j) j$indicatorType$id)), usr, pwd, url, F, usr.who, pwd.who, url.who)

prog_info %<>% append(ind_types)

# User roles -----------------------------------
user_roles <- getDHIS2_Resource('userRoles', usr, pwd, url)

user_roles <- getDHIS2_specificExport(c('CgDgY93dcGU', 'pwKc47NLgNX'), usr, pwd, url, F, usr.who, pwd.who, url.who)
user_groups <- getDHIS2_Resource('userGroups', usr.who, pwd.who, url.who) %>% filter(grepl('ETA', name))
user_groups <- getDHIS2_specificExport(user_groups$id, usr.who, pwd.who, url.who, F)

prog_info$userRoles <- user_roles$userRoles
prog_info$userGroups <- user_groups$userGroups

saveDHIS2_metadataExport(prog_info, '../EpiTech/who-dsi/ETA full export 2018-04-19.json')

# Post the prepared package ------------------------------------------
r <- postDHIS2_metadataPackage(prog_info, usr.who, pwd.who, url.who, strategy = 'CREATE_AND_UPDATE&mergeMode=REPLACE')
content(r, 'text')

# Make a summary excel file with the results of what we pulled -----------------

rpt <- tibble()
for (n in names(prog_info[!grepl('^date$|^system', names(prog_info))])) {
  print(n)
  for (i in prog_info[[n]]) {
    j <- as.data.frame.list(i[grepl("^(id|name)", names(i))])
    j$type <- n
    rpt %<>% bind_rows(j)
  }
}

rpt_summary <- as.data.frame(table(rpt$type))
names(rpt_summary) <- c('type', 'count')

wb <- createWorkbook()
addWorksheet(wb, 'summary')
writeData(wb, 'summary', rpt_summary)
addWorksheet(wb, 'details')
writeData(wb, 'details', rpt)
saveWorkbook(wb, '../EpiTech/who-dsi/ETA full export summary 2018-04-02.xlsx', overwrite=T)
