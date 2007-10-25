echo
echo Running all -3.x test cases:
echo

if [ -z $lua ]; then
	lua=lua
fi

for i in *-3.*.lua; do 
	echo ----- Running $i:
	$lua $i
done


echo
echo -----------------------
echo DONE!
echo
echo '(To point at a specific lua.exe, use "export lua=/path/to/lua" prior to executing runall.sh)'
echo
