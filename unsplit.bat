@echo off
for /F %%i in (split.txt) do move ..\%%i .
del split.txt

