@echo off
::This file was created automatically by CrossIDE to compile with C51.
C:
cd "\CrossIDE\Call51\Bin\lab5\"
"C:\CrossIDE\Call51\Bin\c51.exe" --use-stdout  "C:\CrossIDE\Call51\Bin\lab5\lab5.c"
if not exist hex2mif.exe goto done
if exist lab5.ihx hex2mif lab5.ihx
if exist lab5.hex hex2mif lab5.hex
:done
echo done
echo Crosside_Action Set_Hex_File C:\CrossIDE\Call51\Bin\lab5\lab5.hex
