@echo off
copy calmira.rtf calmira0.rtf > NUL
hcp calmira.hpj
del calmira0.rtf > NUL
echo.
echo Done!
