#!/system/bin/sh

log() {
  printf '%s %s\n' "$(date '+%F %T' 2>/dev/null)" "$*"
}

write_if_exists() {
  [ -e "$1" ] || return 0
  printf '%s\n' "$2" >"$1" 2>/dev/null && log "set $1=$2"
}

read_value() {
  [ -r "$1" ] || return 1
  IFS= read -r _v <"$1" 2>/dev/null || return 1
  printf '%s' "$_v"
}

nearest_freq() {
  target="$1"
  list="$2"
  best=""
  best_diff=""

  for f in $list; do
    case "$f" in ''|*[!0-9]*) continue ;; esac
    diff=$((f - target))
    [ "$diff" -lt 0 ] && diff=$(( -diff ))
    if [ -z "$best" ] || [ "$diff" -lt "$best_diff" ]; then
      best="$f"
      best_diff="$diff"
    fi
  done

  [ -n "$best" ] && printf '%s' "$best"
}

pick_in_range() {
  low="$1"
  high="$2"
  fallback="$3"
  list="$4"
  best=""

  for f in $list; do
    case "$f" in ''|*[!0-9]*) continue ;; esac
    [ "$f" -lt "$low" ] && continue
    [ "$f" -gt "$high" ] && continue
    best="$f"
  done

  if [ -n "$best" ]; then
    printf '%s' "$best"
  else
    nearest_freq "$fallback" "$list"
  fi
}

soc_is_snapdragon_8_elite() {
  soc_model="$(getprop ro.soc.model 2>/dev/null)"
  soc_name="$(getprop ro.product.board 2>/dev/null)$(getprop ro.board.platform 2>/dev/null)$(getprop ro.soc.manufacturer 2>/dev/null)"
  soc_id="$(getprop ro.boot.hardware.sku 2>/dev/null)$(getprop ro.boot.chipname 2>/dev/null)"
  all="$soc_model $soc_name $soc_id"

  case "$(printf '%s' "$all" | tr '[:upper:]' '[:lower:]')" in
    *"8 elite"*|*"sm8750"*|*"sun"*) return 0 ;;
    *) return 1 ;;
  esac
}
