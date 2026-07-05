#!/usr/bin/env bash
# Framework-free unit tests for blurred-background.lua's build_vf().
# Run: bash tests/blurred-background.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUA_SCRIPT="$SCRIPT_DIR/mpv-scripts/blurred-background.lua"

fails=0
check_contains() { # check_contains <description> <expected_substring> <actual>
  if [[ "$3" == *"$2"* ]]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1"
    echo "       expected to contain: [$2]"
    echo "       actual:              [$3]"
    fails=$((fails + 1))
  fi
}

build_vf() { # build_vf <w> <h>  -> prints the generated vf string
  lua -e '
package.preload["mp"] = function()
  return {
    register_event = function() end,
    get_property_number = function() end,
    get_property = function() end,
    set_property = function() end,
    command_native = function() end,
    add_hook = function() end,
  }
end
package.preload["mp.options"] = function()
  return { read_options = function() end }
end
package.preload["mp.utils"] = function()
  return { parse_json = function() end }
end
local mod = dofile("'"$LUA_SCRIPT"'")
print(mod.build_vf('"$1"', '"$2"'))
'
}

landscape="$(build_vf 1920 1080)"
check_contains "landscape: bg cover-scaled to screen size" "scale=1920:1080:force_original_aspect_ratio=increase" "$landscape"
check_contains "landscape: bg downscaled to 1/4 before blur" "scale=480:270,gblur=sigma=20" "$landscape"
check_contains "landscape: bg upscaled back to screen size after blur" "gblur=sigma=20,scale=1920:1080" "$landscape"
check_contains "landscape: fg scaled to fit without upscaling" "scale=1920:1080:force_original_aspect_ratio=decrease" "$landscape"
check_contains "landscape: fg centered over bg" "overlay=(W-w)/2:(H-h)/2" "$landscape"

portrait="$(build_vf 1080 1920)"
check_contains "portrait: quarter-res divides cleanly" "scale=270:480,gblur=sigma=20" "$portrait"

odd="$(build_vf 1921 1081)"
check_contains "non-divisible dims: quarter-res floors down" "scale=480:270,gblur=sigma=20" "$odd"

echo ""
if [[ "$fails" -eq 0 ]]; then
  echo "All tests passed."
else
  echo "$fails test(s) FAILED."
  exit 1
fi
