set Dir_Old=%cd%
cd /D %~dp0

del /s /f *.ps *.dvi *.aux *.toc *.idx *.ind *.ilg *.log *.out *.brf *.blg *.bbl *.lot *.lof *.lsb *.lsg modelo.pdf
xelatex -interaction=nonstopmode modelo
echo ----
makeindex modelo.idx
echo ----
xelatex -interaction=nonstopmode modelo

setlocal enabledelayedexpansion
set count=8
:repeat
set content=X
for /F "tokens=*" %%T in ( 'findstr /C:"Rerun LaTeX" modelo.log' ) do set content="%%~T"
if !content! == X for /F "tokens=*" %%T in ( 'findstr /C:"Rerun to get cross-references right" modelo.log' ) do set content="%%~T"
if !content! == X goto :skip
set /a count-=1
if !count! EQU 0 goto :skip

echo ----
xelatex -interaction=nonstopmode modelo
goto :repeat
:skip
endlocal
makeindex modelo.idx
bibtex modelo
xelatex -interaction=nonstopmode modelo
bibtex modelo
xelatex -interaction=nonstopmode modelo
sort modelo.lsg > modelo2.lsg
del modelo.lsg
copy modelo2.lsg modelo.lsg
del modelo2.lsg
xelatex -interaction=nonstopmode modelo
cd /D %Dir_Old%
set Dir_Old=
