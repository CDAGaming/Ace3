@echo off
for /D %%i in (*-?.*) do call :splitone %%i
goto :eof

:splitone
echo Splitting off %1...
echo %1 >> split.txt
echo ##Interface: 20300 > %1\%1.toc
echo ##Title:Lib:%1 >> %1\%1.toc
if not "%1" == "CallbackHandler-1.0" echo ##OptionalDeps:CallbackHandler-1.0 >> %1\%1.toc
echo ##LoadWith:Ace3 >> %1\%1.toc
echo %1.xml >> %1\%1.toc
move %1 ..
goto :eof