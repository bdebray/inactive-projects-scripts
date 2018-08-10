# Agile Central: Inactive Projects Export

This script will retrieve a list of Projects for a Workspace and the total number of artifact changes since a provided date.

## Getting Started

### Prerequisites

Ensure ruby is installed. The script requires the following gems:

* [json](https://rubygems.org/gems/json)
* [rally_api](https://rubygems.org/gems/rally_api)
* [csv](https://rubygems.org/gems/csv)

### Installing & Running

1. Download or clone this repository
2. Update the provided config.json file (rename the file, if desired):
   - **api_key** (Required): Specify an API Key with sufficient access (write access if automatically closing projects)
   - **workspace** (Required): Specify a Workspace Name
   - **project** (Optional): Specify a Project Name; the script will retrieve data for the specified project and all descendant projects instead of the entire Workspace
   - **active-since** (Required): Specify a date, in YYYY-MM-DD format, to query how many artifact changes have been made since the provided date
   - **most_recent_creation_date** (Optional): Specify a date, in YYYY-MM-DD format, to only include projects that were created prior to the provided date. If not needed, provide an empty value or null
   - **csv-file-name** (Required): Use the default provided filename or rename, if desired. Must contain the ".csv" extension
   - **exclude-parent-project** (Required): Exclude/Include parent projects (those with no open children) by setting the value to true/false
   - **max-artifact-count** (Optional): Only include projects that have less than a specified number of artifact changes. The results will exclude any projects that have had more changes than the provided integer number. For no limit, set the value to null.
3. Open terminal/console, navigate to the downloaded/cloned directory and run `ruby inactive-projects.rb [config file name]` or `ruby inactive-projects.rb example_config.json`, if using the default config file name. 
4. The csv output and log file will be written in the same directory as the script.
