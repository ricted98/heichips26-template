# Copyright 2026 Riccardo Tedeschi
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

/^\+incdir\+/ { inc[++ni] = substr($0, 9); next }
/^\+define\+/ { def[++nd] = substr($0, 9); next }
/^[ \t]*$/    { next }
              { src[++ns] = $0 }

END {
  emit("VERILOG_FILES",        src, ns)
  emit("VERILOG_INCLUDE_DIRS", inc, ni)
  emit("VERILOG_DEFINES",      def, nd)
}

function emit(key, arr, n,   i) {
  if (n == 0) { print key ": []"; return }
  print key ":"
  for (i = 1; i <= n; i++) print "  - \"" arr[i] "\""
}
