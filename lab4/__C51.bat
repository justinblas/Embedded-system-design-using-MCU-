@echo off
::This file was created automatically by CrossIDE to compile with C51.
C:
cd "\CrossIDE\Call51\Bin\lab4\"
"C:\CrossIDE\Call51\Bin\c51.exe" --use-stdout  "C:\CrossIDE\Call51\Bin\lab4\ADC_EFM8.c"
if not exist hex2mif.exe goto done
if exist ADC_EFM8.ihx hex2mif ADC_EFM8.ihx
if exist ADC_EFM8.hex hex2mif ADC_EFM8.hex
:done
echo done
echo Crosside_Action Set_Hex_File C:\CrossIDE\Call51\Bin\lab4\ADC_EFM8.hex
