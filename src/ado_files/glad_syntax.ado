*! version 1.2 FEB2020 EduAnalytics eduanalytics@worldbank.org
*! Author: Diana Goldemberg

cap program drop glad_syntax
program define   glad_syntax, nclass

  /* This program performs the most common parsing/joining operations in
  our particular filename convention for the GLAD collection. Example:

    COMPONENTS
      country       = BRA
      year          = 2013
      assessment    = LLECE
      master        = v01_M
      adaptation    = v02_A_GLAD
      module        = ALL
      extension     = .dta

    COMBINATIONS
      filename      = BRA_2013_LLECE_v01_M_v02_A_GLAD_ALL.dta
      surveymodule  = BRA_2013_LLECE_v01_M_v02_A_GLAD_ALL
      surveyvintage = BRA_2013_LLECE_v01_M_v02_A_GLAD
      surveyid      = BRA_2013_LLECE_v01_M
      survey        = BRA_2013_LLECE
      vintage       = v01_M_v02_A_GLAD
  */

  * Declare error codes
  local syntax_error 2222

  * Check that the syntax specified is valid
  gettoken subcmd options : 0 , parse(" ,")
  
  if `"`subcmd'"' == "" {
    noisily display as error `"{bf:glad_syntax} must be followed by a subcommand (either -parse- or -join-)."'
    exit `syntax_error'
  }
  else if inlist(`"`subcmd'"', "join", "parse") == 0 {
    noisily display as error `"{bf:glad_syntax} {bf:`subcmd'} is unrecognized. Valid subcommands are parse or join."'
    exit `syntax_error'
  }
  else if inlist(`"`subcmd'"', "join", "parse") == 1 & (`"`options'"' == "" | strpos(`"`options'"', ",") == 0) {
    noisily display as error `"{bf:glad_syntax} {bf:`subcmd'} must be followed by , options. Check {bf:help glad_syntax} for more details."'
    exit `syntax_error'
  }

  * Runs the subcommand
  glad_`subcmd' `options'

end


********************************************************************************

cap program drop glad_parse
program define   glad_parse, rclass


  syntax, [filename(string) surveymodule(string) surveyvintage(string) ///
           surveyid(string) survey(string) vintage(string)]

  *-------------------------------------------------------------------------
  * Check syntax
  *-------------------------------------------------------------------------
  
  * All possible options from the syntax
  local possible_options "filename surveymodule surveyvintage surveyid survey vintage"
  * All individual components that form a filename
  local possible_components "country year assessment master adaptation module extension"

  * Check that 1 and only 1 option was chosen
  local n_chosen_options = 0
  foreach option of local possible_options {
    if "``option''" != "" {
      local chosen_option = "`option'"
      local ++n_chosen_options
    }
  }
  if `n_chosen_options' != 1 {
    noi display as error "Parse must be combined with one and only one option from {it: `possible_options'}."
    exit `syntax_error'
  }
  
  * Models for helpful error messages
  local err_survey        "survey(ccc_yyyy_*)"
  local err_surveyid      "surveyid(ccc_yyyy_*_v??_M)" 
  local err_surveyvintage "surveyvintage(ccc_yyyy_*_v??_M_v??_A_adapt)" 
  local err_vintage       "vintage(v??_M_v??_A_adapt)" 
  local err_surveymodule  "surveymodule(ccc_yyyy_*_v??_M_v??_A_adapt_mod)" 
  local err_filename      "filename(ccc_yyyy_*_v??_M_v??_A_adapt_mod.ext)" 
  
  *-------------------------------------------------------------------------
  * Options are parsed sequentially, because they are nested
  *-------------------------------------------------------------------------

  * Parses the extension from surveymodule if there is an extension, when
  * there is no extension, using filename() or surveymodule() would be equal
  if "`filename'" != "" {
    mata : st_local("extension", pathsuffix(`"`filename'"'))
    if `"`extension'"' != "" mata: st_local("surveymodule", pathrmsuffix(`"`filename'"'))
    else local surveymodule "`filename'"
    return local extension    "`extension'"
    return local surveymodule "`surveymodule'"
  }

  * Parses the module from surveyvintage on the last Underscore
  if "`surveymodule'" != "" {
    local lastU = 1 + strlen("`surveymodule'") - strpos(strreverse("`surveymodule'"), "_")
    local module = substr("`surveymodule'", 1 + `lastU', .)
    local surveyvintage = substr("`surveymodule'", 1, `lastU' - 1)
    return local module        "`module'"
    return local surveyvintage "`surveyvintage'"
  }

  * Parses the vintage from the survey at the 3rd Underscore
  * And because survey has the 2nd undescore at character 9, we start looking at 10
  if "`surveyvintage'" != "" {
    local thirdU = 9 + strpos(substr("`surveyvintage'", 10, .), "_")
    local survey = substr("`surveyvintage'", 1, `thirdU' - 1)
    local vintage = substr("`surveyvintage'", 1 + `thirdU', .)
    return local survey  "`survey'"
    return local vintage "`vintage'"
  }

  * If surveyid was specified, it is not nested on the above
  * so it's dealt with separately, similar to the surveyvintage case,
  * parsing at the 3rd underscore
  if "`surveyid'" != "" {
    local thirdU = 9 + strpos(substr("`surveyid'", 10, .), "_")
    local survey = substr("`surveyid'", 1, `thirdU' - 1)
    return local master = substr("`surveyid'", 1 + `thirdU', .)
    return local survey  "`survey'"
  }

  * Vintage must match the structure v??_M_v??_A_*
  * with an extra ? needed to force at least one character in adaptation name
  if "`vintage'" != "" {
    cap assert strmatch("`vintage'", "v??_M_v??_A_?*") == 1
    if _rc == 0 {
      return local master     = substr("`vintage'", 1, 5)
      return local adaptation = substr("`vintage'", 7, .)
    }
    else {
      noi display as error "Parsing failed. It does not follow the convention. Expected {it:`err_`chosen_option''}."
      exit `syntax_error'
    }
  }

  * Survey must match the structure ccc_yyyy_assessment*
  * Forces country to be 3 chars and year 4 chars, but assessment can be whatever
  if "`survey'" != "" {
    cap assert strmatch("`survey'", "???_????_?*") == 1
    if _rc == 0 {
      return local country    = substr("`survey'", 1, 3)
      return local year       = substr("`survey'", 5, 4)
      return local assessment = substr("`survey'", 10, .)
    }
    else {
      noi display as error "Parsing failed. It does not follow the convention. Expected {it:`err_`chosen_option''}."
      exit `syntax_error'
    }
  }

end


********************************************************************************


cap program drop glad_join
program define   glad_join, rclass

  syntax, [country(string) year(string) assessment(string) ///
           survey(string) master(string) adaptation(string) ///
           vintage(string) module(string) extension(string)]


  *--------------------------------------------------------------------------
  * The survey = country_year_assessment should be given or created
  *--------------------------------------------------------------------------
  * If survey is not defined, compose it from the 3 components
  if "`survey'" == "" {
    if ("`country'" != "" & "`year'" != "" & "`assessment'" != "") {
      local survey "`country'_`year'_`assessment'"
      * If survey is not following the convention, stops and exit
      if strmatch("`survey'", "???_????_?*") == 0 {
        noi display as error "Join failed. It does not follow the convention. Expected {it:country(ccc) year(yyyy) assessment(*)}."
        exit `syntax_error'
      }
    }
    else {
      noi display as error "Could not join, for lack of information. Either {it:country year assessment} or {it:survey} were expected."
      exit `syntax_error'
    }
  }

  * If the survey is defined it must make sense. None of the 3 components
  * is needed but if any is used, they must be compatible
  else {
    cap assert strmatch("`survey'", "???_????_?*") == 1
    if _rc {
      noi display as error "Join failed. It does not follow the convention. Expected {it:survey(ccc_yyyy_*)}."
      exit `syntax_error'
    }
    if "`country'" != "" & strpos("`survey'", "`country'") != 1 {
      noi display as error "Could not join. You specified {it:survey(`survey')} and {it:country(`country')}, which are incompatible. Please specify only one of them, or a compatible pair."
      exit `syntax_error'
    }
    if "`year'" != "" & strpos("`survey'", "`year'") != 5 {
      noi display as error "Could not join. You specified {it:survey(`survey')} and {it:year(`year')}, which are incompatible. Please specify only one of them, or a compatible pair."
      exit `syntax_error'
    }
    if "`assessment'" != "" & strpos("`survey'", "`assessment'") != 10 {
      noi display as error "Could not join. You specified {it:survey(`survey')} and {it:assessment(`assessment')}, which are incompatible. Please specify only one of them, or a compatible pair."
      exit `syntax_error'
    }
  }


  
  *--------------------------------------------------------------------------
  * Join further elements in the proper order
  *--------------------------------------------------------------------------

  * If vintage is given, combine it with survey in a single step
  if ("`vintage'" != "") {
    local surveyvintage = "`survey'_`vintage'"

    * If vintage is specified, master and adaptation are not needed
    * but if any is used, they must be compatible
    if "`master'" != "" & strpos("`vintage'", "`master'") != 1 {
      noi display as error "Could not join. You specified {it:master(`master')} and {it:vintage(`vintage')}, which are incompatible. Please specify only one of them, or a compatible pair."
      exit `syntax_error'
    }
    if "`adaptation'" != "" & strpos(strreverse("`vintage'"), strreverse("`adaptation'")) != 1 {
      noi display as error "Could not join. You specified {it:adaptation(`adaptation')} and {it:vintage(`vintage')}, which are incompatible. Please specify only one of them, or a compatible pair."
      exit `syntax_error'
    }
  }

  * If vintage is not given, tries to get to surveyvintage in two steps
  else {
    if "`master'" != "" {
      local surveyid = "`survey'_`master'"
      if "`adaptation'" != "" local surveyvintage = "`surveyid'_`adaptation'"
    }
  }

  * Tentativelly add the module if specified
  if "`surveyvintage'" != "" & "`module'" != "" {
    local surveymodule = "`surveyvintage'_`module'"
  }

  * Tentativelly add the extension if specified
  if "`surveymodule'" != "" & "`extension'" != "" {
    * Start the extension with . if not yet at the beginning
    if substr("`extension'",1,1) != "." local extension ".`extension'"
    local filename = "`surveymodule'`extension'"
  }

  *--------------------------------------------------------------------------
  * Return every possible output which is not empty
  *--------------------------------------------------------------------------
  local possible_outputs "filename surveymodule surveyvintage surveyid survey"
  foreach output of local possible_outputs {
    if "`output'" != "" {
      return local `output' = "``output''"
    }
  }

end
