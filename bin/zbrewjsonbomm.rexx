/* REXX */
/* 
 * Parse a JSON stream for SMP/E Library datasets and write out a set of key/value pairs (one per line)
 * See: http://tech.mikefulton.ca/WebEnablementToolkit for details on the REXX JSON parsing services
 */

trace 'o'
Arg swname .

  if (swname = '') then do
    call SayErr 'Syntax: zbrewjsonbom <swname>'
    call SayErr '  Where <swname> is the name of the software product, e.g. ZHW110'
    call SayErr '  The JSON key/value pairs are read in from stdin'
    call SayErr '  The parsed key/value pairs are written out to stdout'
    return 4
  end

  call hwtcalls "on"

  parserHandle = ''
  objectHandle = ''
  rc = readJSON(parserHandle, objectHandle)
  if (rc <> 0) then do
    return rc
  end

  rc = FindName(swname, parserHandle, objectHandle)
  if (rc <> 0) then do
    return rc
  end

  return 0

ReadJSON:        
  parserHandle=arg(1)
  objectHandle=arg(2)
  address hwtjson "hwtConst ",
    "returnCode ",
    "diagArea."
  if (rc <> 0 | returnCode <> HWTJ_OK) then do
    call Error 'Internal Error: Unable to get HWTJSON constants', diagArea.
    return 16
  end

  address hwtjson "hwtjinit ",
    "returnCode ",
    "parserHandle ",
    "diagArea."
  if (rc <> 0 | returnCode <> HWTJ_OK) then do
    call Error 'Internal Error: Unable to initialize HWT', diagArea.
    return 16
  end

  address mvs 'execio * diskr stdin (stem data. finis'
  stream=''
  do i=1 to data.0
    stream=stream||data.i
  end

  address hwtjson "hwtjpars ",
    "returnCode ",
    "parserHandle ",
    "stream ",
    "diagArea." 
  parseRC=rc

  if (rc <> 0 | returnCode <> HWTJ_OK) then do
    call Error 'JSON Input is Invalid.', diagArea.
    call SayErr stream
    return 8
  end

  objectHandle=0
  objectEntryIndex=0
  address hwtjson "hwtjgoen",
    "returnCode",        
    "parserHandle",                
    "objectHandle",            
    "objectEntryIndex",                      
    "entryName",              
    "entryValueHandle",
    "diagArea."
  if (rc <> 0 | returnCode <> HWTJ_OK) then do
    call Error 'Internal Error: Unable to retrieve root JSON object.', diagArea.
    return 16
  end
  return 0

FindName: 
  swname = arg(1)
  parserHandle = arg(2)
  objectHandle = arg(3)

  diagArea. = ''
  searchName="name"
  do until (searchResultValue = swname)
    address hwtjson "hwtjsrch ",
    "returnCode",
    "parserHandle",
    "HWTJ_SEARCHTYPE_OBJECT",
    "searchName",
    "objectHandle",
    "0",
    "searchResult",
    "diagArea."
    if (rc <> 0 | returnCode <> HWTJ_OK) then do
      call SayErr 'Unable to find swname: ' || swname
      return 4
    end

    address hwtjson "hwtjgjst",
      "returnCode",
      "parserHandle",
      "searchResult",
      "searchResultType",
      "diagArea."
    if (rc <> 0 | returnCode <> HWTJ_OK) then do
      call Error 'Internal Error: Unable to retrieve type for name entry: ' || objectEntryIndex, diagArea.
      return 16
    end
    if (searchResultType <> 'HWTJ_STRING_TYPE') then do
      call SayErr 'Name: ' || searchName || ' is not of string type. Only string values can be specified. Key ignored.'
      return 16
    end

    address hwtjson "hwtjgval",
      "returnCode",
      "parserHandle",
      "searchResult",
      "searchResultValue",
      "diagArea."
    if (rc <> 0 | returnCode <> HWTJ_OK) then do
      call Error 'Unable to retrieve value for key/value pair entry: ' || objectEntryIndex, diagArea.
      return 16
    end
    objectHandle=searchResult
    say "Name: " || searchResultValue 
  end
  return 0

SayErr: Procedure
  Parse Arg text
  data.1 = text
  data.0 = 1
  address mvs 'execio 1 diskw stderr (stem data.' 
  return 0

Error: Procedure Expose diagArea.
Parse Arg msg, diagArea
  call SayErr msg
  call SayErr diagArea.HWTJ_ReasonDesc 
  return 0
