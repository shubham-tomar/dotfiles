# ANSI formatting function (\033[<code>m)
# 0: reset, 1: bold, 4: underline, 22: no bold, 24: no underline, 31: red, 33: yellow
omz_f() {
  [ $# -gt 0 ] || return
  IFS=";" printf "\033[%sm" $*
}
# If stdout is not a terminal ignore all formatting
[ -t 1 ] || omz_f() { :; }

# Protect against non-zsh execution of Oh My Zsh (use POSIX syntax here)
[ -n "$ZSH_VERSION" ] || {
  omz_ptree() {
    # Get process tree of the current process
    pid=$$; pids="$pid"
    while [ ${pid-0} -ne 1 ] && ppid=$(ps -e -o pid,ppid | awk "\$1 == $pid { print \$2 }"); do
      pids="$pids $pid"; pid=$ppid
    done

    # Show process tree
    case "$(uname)" in
    Linux) ps -o ppid,pid,command -f -p $pids 2>/dev/null ;;
    Darwin|*) ps -o ppid,pid,command -p $pids 2>/dev/null ;;
    esac

    # If ps command failed, try Busybox ps
    [ $? -eq 0 ] || ps -o ppid,pid,comm | awk "NR == 1 || index(\"$pids\", \$2) != 0"
  }

  {
    shell=$(ps -o pid,comm | awk "\$1 == $$ { print \$2 }")
    printf "$(omz_f 1 31)Error:$(omz_f 22) Oh My Zsh can't be loaded from: $(omz_f 1)${shell}$(omz_f 22). "
    printf "You need to run $(omz_f 1)zsh$(omz_f 22) instead.$(omz_f 0)\n"
    printf "$(omz_f 33)Here's the process tree:$(omz_f 22)\n\n"
    omz_ptree
    printf "$(omz_f 0)\n"
  } >&2

  return 1
}
