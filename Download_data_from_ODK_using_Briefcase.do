/* ============================================================================\
|                                                                              |
|   Filename:       Download_data_from_ODK_using_Briefcase.do                  |
|   Author:         Benjamin Faguer (@benjaminFaguer)                          |
|   Date:           11 August 2020                                             |
|   Project name:   Stata_ODK                                                  |
|   Objective:      Download data from ODK programmatically using the          |
|                   command-line interface provided with ODK Briefcase.        |
|   Revised by:                                                                |
|   Revision date:                                                             |
|   Stata version:  Stata IC version 15.1                                      |
|   Script version: 1.0                                                        |
|                                                                              |
|   Input:                                                                     |
|   Output:                                                                    |
|   Master file:                                                               |
|                                                                              |
\=============================================================================*/
version 15
set more off
clear

// I. Preparation
// ==============
/* Before running the rest of the script, you need to adapt it to your project's 
   needs by editing a few variables/local macros.

   1. Set your working directory
   -----------------------------
   Storing in a local macro means we only have to change it in one place
   and that it will always remain consistent (no typos).                      */

global workDir "~/Documents/Stata_ODK"

/* 2. Set your private key
   -----------------------
   This macro is needed if you use encrypted ODK forms.
   You need to set the filename to match your private key.
   Make sure this file is not synced to any file sharing platform.
   For safety purposes, any file ending in `.pem` will be ignored in 
   this repo.                                                                */

local pem = "$workDir/resources/Private_Key.pem"

/* 3. Edit your form list
   ----------------------
   Here is the list of form IDs to be processed by the script.
   They can be found in the ODK form definitions, in the `settings` worksheet
   or on your ODK Aggregate instance, in the Form Management tab.
   The current values are examples and need to be changed to match your 
   project.                                                                   
   It is stored in a global macro so it can be passed on to the next do-file. */

global formId ODKform1_1 ///
              ODKform2_1 ///
              ODKform3_1

/* 4. Write your ODK Aggregate credentials in a separate csv file
   --------------------------------------------------------------
   For safety purposes, your server credentials should never be stored as 
   plain text in your do-files.
   It is better to store them in a csv file, placed in a local folder (i.e. not 
   shared on Github, Dropbox, Onedrive…)
   If you use git, remember to add it to your .gitignore.
   For this example it is added to the repo, but remember not to do it in 
   production.                                                                
   If you want to edit the name of the file where the credentials are stored,
   edit the following macro. 
   In any case, please use the same structure as the example file, 
   or better yet, just edit it.                                               */

local serverCred ./ODK_Aggregate_Credentials.csv

// -----------------------------------------------------------------------------

// Set up the rest of the macros needed for the script
// ---------------------------------------------------
cd $workDir
// Create the needed subfolders if they don't exist already
cap mkdir "$workDir/csv"
cap mkdir "$workDir/resources"

// We'll make sure you have ODK Briefcase downloaded to your computer, with a 
// version that is known to work with this script.
local briefcase_version "v1.16.3"
cap confirm file "$workDir/ODK-Briefcase-`briefcase_version'.jar"
if _rc != 0 copy "https://github.com/opendatakit/briefcase/releases/download/`briefcase_version'/ODK-Briefcase-`briefcase_version'.jar"                                                         ///
    "$workDir/ODK-Briefcase-`briefcase_version'.jar"

// Import server credentials from the csv file
import delimited "`serverCred'", bindquote(strict) varnames(1) encoding(utf8) 
local url = url in 1
local user = user in 1
local password = password in 1

// A few other local macros needed for the script
local briefcase_path = "$workDir/ODK-Briefcase-`briefcase_version'.jar"
local storage_dir = "$workDir/ODK"
local export_dir = "$workDir/csv"


// II. Download and Export
// =======================
/* Check if the data was already downloaded today
   First, import the 'date.csv' file, which holds the date when the data was 
   last downloaded.
   If the date is the same, this step is skipped and we move on to the next 
   do-file. This is meant to shorten the time it takes to run the whole script
   if you have a lot of different forms, and you need to re-run your script 
   without re-downloading everything.
   
   Another thing to notice is that every form ID will get it's own ODK_Briefcase
   storage directory. This is meant to circumvent an issue with Briefcase when 
   several forms have a different ID, but the same title.                     */
   
import delimited "./resources/date_dl.csv", varnames(1) clear 
if date != "`c(current_date)'" {
    di "Downloading and exporting data from Aggregate…"
	
	// Download data from Aggregate
    // ----------------------------
    foreach form of global form_id {
        shell java -jar `briefcase_path' -plla -id `form' -sd `storage_dir'"_"`form' ///
            -url `url' -u `user' -p `passwd' -mhc 8 
        di "Downloaded `form'"
    }
	
    // Export the data to csv files
    // ----------------------------
    foreach form of global form_id {
        shell java -jar `briefcase_path' -e -id `form' -sd `storage_dir'"_"`form' ///
            -ed `export_dir' -f "`form'.csv" -pf `pem' -oc
        di "Exported `form'"
    }
	
    di "Data downloaded and exported!"

    // Once the data has been downloaded, write the date to the file so it's not
    // run again today.
    !printf "date,\n`c(current_date)'" > "./resources/date_dl_PTx.csv"
}

// All done, next step is going to be using odkmeta, in the next do-file.
