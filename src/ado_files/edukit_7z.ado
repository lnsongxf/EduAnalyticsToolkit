*! version 1.2 FEB2020 EduAnalytics eduanalytics@worldbank.org
*! Author: Diana Goldemberg

cap program drop edukit_7z
program define   edukit_7z, rclass

  /* This is a wrapper to use a shell of 7 zip in Stata,
  given that its location was already set by -whereis-

  It only takes one argument, the command line that one could type
  if manually opening a prompt and using 7 zip - in the same syntax.

  When cmd is not specified, it is equivalent to only checking the installation.

  For info on how the syntax rules for 7z:
  https://sevenzip.osdn.jp/chm/cmdline/syntax.htm

  Usual options:
  * command e   = Extract (without folder structure)
  * switch -r   = Recurse subdirectories
  * switch -aoa = Overwrite all existing files without prompt
  * switch -o   = Set output directory

  */

  syntax, [ cmd(string)]

  *--------------------------------------------------------------------
  * Check the location of 7-Zip executable stored by -whereis-
  * and give more informative error messages for the most common errors
  *--------------------------------------------------------------------

  cap whereis 7z

  * -whereis- has something stored as 7z
  if _rc == 0 {

    * Local to be used in the shell is slightly different from what whereis stores
    local whereis_7z "`r(7z)'"

    * Likely, whereis results ends in "7z.exe", and it should end in "7z"
    if substr("`whereis_7z'", -6, 6) == "7z.exe" {
      local whereis_7z = substr("`whereis_7z'", 1, strlen("`whereis_7z'") -4)
    }
    * If it's not ending in "7z.exe", the user probably messed up when storing whereis
    else {
      noi dis as error `"{phang}Instead of returning {it: path/7z.exe}, {it: whereis 7z} is currently returning: `whereis_7z'. Please specify -whereis- again, for example: {it: whereis 7z "C:\Program Files\7-Zip\7z.exe"} if you installed the full version or {it: whereis 7z "C:\Users\JohnDoe\Portable_Apps\7-ZipPortable\App\7-Zip\7z.exe"} if you installed the portable version.{p_end}"'
      exit 601
    }

    * The path may have spaces, if that's the case we need to adorn with extra quotes
    if wordcount(`"`whereis_7z'"') > 1 {
      local whereis_7z `" "`whereis_7z'" "'
    }

  }

  * -whereis- is not installed
  else if _rc == 199 {
    noi dis as error `"{phang}To automatically extracts .zip and .rar files, this routine requires the freeware 7-Zip to be installed in the computer and its location stored by the command -whereis-. You can install -whereis- through {it: ssc install whereis}.{p_end}"'
    exit 199
  }

  * -whereis- is installed, but the locatin of 7z is not stored
  else if _rc == 601 {
    noi dis as error `"{phang}You must store the location of the freeware 7-Zip through the command -whereis-. For example, {it: whereis 7z "C:\Program Files\7-Zip\7z.exe"} if you installed the full version ({it: https://www.7-zip.org/}) or {it: whereis 7z "C:\Users\JohnDoe\Portable_Apps\7-ZipPortable\App\7-Zip\7z.exe"} if you installed the portable version ({it: https://portableapps.com/apps/utilities/7-zip_portable}). The installation of the portable version does not require admin privileges.{p_end}"'
    exit 601
  }

  * For any other error case gets the default error message
  else if _rc != 0 exit _rc


  *----------------------------------------------
  * Finally, calls the shell with the command line
  *----------------------------------------------
  local full_cmd `"`whereis_7z' `cmd'"'
  ! `full_cmd'

  * For debugging ease
  return local cmd `full_cmd'

end
