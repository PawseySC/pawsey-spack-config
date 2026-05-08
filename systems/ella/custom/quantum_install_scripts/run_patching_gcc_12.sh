
function gccpatch()
{
  local file=$1
  echo "Patching ${file}"
  sed -i \
  's/#include <memory>/#ifdef __noinline__\
      #define GCC12_RESTORE_NOINLINE\
      #undef __noinline__\
    #endif\
    #include <memory>\
    #ifdef GCC12_RESTORE_NOINLINE\
      #undef GCC12_RESTORE_NOINLINE\
      #define __noinline__ _attribute((noinline))\
    #endif/g' \
    $file
}

function patchallfiles()
{
	local files=($(grep -rl "#include <memory>" build))
	for file in ${files[@]}
	do
		gccpatch $file
	done
}
