
' This script creates an "Archived" subdirectory and copies the given file there.
' The name of the copy gets the current date and time appended to it.
'
' In order to add this script to Windows Explorer's "Send to" menu, place a shortcut to it
' in the following directory:
'   %APPDATA%\Microsoft\Windows\SendTo
' (or more correctly, to the folder pointed by the registry key
'  HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\SendTo )
'
' Alternatively, the user can drag a file with the mouse to this .vbs script file
' in order to copy it to the old versions archive.
'
' Copyright (c) 2016 R. Diez - Licensed under the GNU AGPLv3

Option Explicit

' Set here the user language to use. See GetMessage() for a list of language codes available.
const language = "eng"

Function GetMessage ( msgEng, msgDeu, msgSpa )

  Select Case language
    Case "eng"  GetMessage = msgEng
    Case "deu"  GetMessage = msgDeu
    Case "spa"  GetMessage = msgSpa
    Case Else   GetMessage = msgEng
      MsgBox "Invalid language.", vbOkOnly + vbError, "Error"
      WScript.Quit( 0 )
  End Select

End Function


Function Abort ( errorMessage )
  MsgBox errorMessage, vbOkOnly + vbError, GetMessage( "Error", "Fehler", "Error" )
  WScript.Quit( 0 )
End Function


Function PadNumberWithLeadingZeros ( numberAsStr, digitCount )
  If Len( numberAsStr ) < digitCount Then
    PadNumberWithLeadingZeros = String( digitCount - Len( numberAsStr ), "0" ) & numberAsStr
  Else
    PadNumberWithLeadingZeros = numberAsStr
  End If
End Function


Function CopyFile ( filenameSrc, filenameDest )

  On Error Resume Next

  objFSO.CopyFile filenameSrc, filenameDest

  if Err.Number <> 0 then
    Abort GetMessage( "Error copying file:", _
                      "Fehler beim Kopieren der Datei:", _
                      "Error al copiar el archivo:" ) & _
          vbCr & vbCr & filenameSrc & vbCr & vbCr & _
          GetMessage( "To:", _
                      "Nach:", _
                      "A:" ) & _
          vbCr & vbCr & filenameDest & vbCr & vbCr & _
          GetMessage( "The error was:", _
                      "Der Fehler war:", _
                      "El error fue:" ) & _
          " " & Err.Description
  end if

  On Error Goto 0

End Function


Function CreateDirectoryIfDoesNotExist ( dirname )

  if objFSO.FolderExists( dirname ) Then
    exit function
  end if

  On Error Resume Next

  objFSO.CreateFolder( dirname )

  if Err.Number <> 0 then
    Abort GetMessage( "Error creating folder:", _
                      "Fehler beim Erstellen des Ordners:", _
                      "Error al crear la carpeta:" ) & _
          vbCr & vbCr & dirname & vbCr & vbCr & _
          GetMessage( "The error was:", _
                      "Der Fehler war:", _
                      "El error fue:" ) & _
          " " & Err.Description
  end if

  On Error Goto 0

End Function


' ------ Entry point ------

dim archivedDirName
archivedDirName = GetMessage( "Archived", "Archiviert", "Archivado" )

Dim args
Set args = WScript.Arguments

if args.length = 0 then
  Abort GetMessage( "Wrong number of command-line arguments. Please specify a file to process.", _
                    "Falsche Anzahl von Befehlszeilenargumenten. Bitte geben Sie eine zu verarbeitende Datei an.", _
                    "Número incorrecto de argumentos de línea de comandos. Especifique un archivo a procesar." )
elseif args.length <> 1 then
  Abort GetMessage( "Wrong number of command-line arguments. This script can only process one file at a time.", _
                    "Falsche Anzahl von Befehlszeilenargumenten. Dieses Skript kann nur eine Datei auf einmal verarbeiten.", _
                    "Número incorrecto de argumentos de línea de comandos. Este programa solamente puede procesar un archivo a la vez." )
end if

dim srcFilename
srcFilename = args( 0 )

dim objFSO
set objFSO = CreateObject( "Scripting.FileSystemObject" )

dim srcFilenameAbs
srcFilenameAbs = objFSO.GetAbsolutePathName( srcFilename )

if not objFSO.FileExists( srcFilenameAbs ) Then
  Abort GetMessage( "File does not exist:", _
                    "Die Datei existiert nicht:", _
                    "El archivo no existe:" ) & _
                    vbCr & vbCr & srcFilenameAbs
end if

dim objFile
set objFile = objFSO.GetFile( srcFilenameAbs )

dim archivedDirnameAbs
archivedDirnameAbs = objFSO.BuildPath( objFSO.GetParentFolderName( objFile ), archivedDirName )

CreateDirectoryIfDoesNotExist archivedDirnameAbs

dim currentDateTime
currentDateTime = Now

const NoDecimalPlaces = 0
const UseLeadingZeros = -1

dim formattedDateTime

formattedDateTime = PadNumberWithLeadingZeros( Year  ( currentDateTime ), 4 ) & "-" & _
                    PadNumberWithLeadingZeros( Month ( currentDateTime ), 2 ) & "-" & _
                    PadNumberWithLeadingZeros( Day   ( currentDateTime ), 2 ) & "-" & _
                    PadNumberWithLeadingZeros( Hour  ( currentDateTime ), 2 ) & ""  & _
                    PadNumberWithLeadingZeros( Minute( currentDateTime ), 2 ) & ""  & _
                    PadNumberWithLeadingZeros( Second( currentDateTime ), 2 )

dim archivedFilename
archivedFilename = objFSO.BuildPath( archivedDirnameAbs, _
                                     objFSO.GetBaseName( objFile ) & "-" & formattedDateTime & "." & objFSO.GetExtensionName( objFile ) )

CopyFile srcFilenameAbs, archivedFilename

MsgBox GetMessage( "File created:", _
                   "Erstellte Datei:", _
                   "Archivo creado:" ) & _
         vbCr & vbCr & archivedFilename, _
       vbOkOnly + vbInformation, _
       GetMessage( "File created", "Erstellte Datei", "Archivo creado" )

WScript.Quit( 0 )
