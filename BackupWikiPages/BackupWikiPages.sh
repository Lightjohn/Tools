#!/bin/bash

# This script downloads a set of Wiki pages in several formats from a MediaWiki server.
#
# Usage:
#
# First of all, you will have to modify function 'place_your_own_urls_here' below.
#
# This script takes the download destination directory as the one and only argument.
#
# For maximum comfort, see companion script BackupExampleWithRotateDir.sh , which
# uses RotateDir.pl in order to automatically rotate the backup directories.
#
# Motivation:
#
# During the past years, I have written quite a few Wiki pages on a public MediaWiki server,
# and I wanted to back up the whole set at once. After I amend a page or create a new one,
# I want to re-run the backup process without too much fuss. This way, if the Wiki server
# suddenly disappears, it should be easy to get my pages published again
# on the next server that comes along.
#
# Besides, having offline copies of your Wiki pages in several formats allows you to consult,
# search or print them without Internet access.
#
#
# Copyright (c) 2014 R. Diez
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License version 3 as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License version 3 for more details.
#
# You should have received a copy of the GNU Affero General Public License version 3
# along with this program.  If not, see L<http://www.gnu.org/licenses/>.

set -o errexit
set -o nounset
set -o pipefail


place_your_own_urls_here ()
{
  COMMON_PREFIX="http://rdiez.shoutwiki.com/w/index.php?title="

  # Sometimes the first page's URL has a different structure.
  add_page_url "Main_Page" "${COMMON_PREFIX}Rdiez's_Personal_Wiki"


  # add_page() uses variable PREFIX.
  PREFIX="$COMMON_PREFIX"

  add_page "Should_I_assert_against_a_NULL_pointer_argument_in_my_C%2B%2B_function%3F"
  add_page "My_embedded_software_never_stops,_so_I_don%27t_need_to_implement_a_proper_shutdown_logic"
  add_page "How_to_write_maintainable_initialisation_and_termination_code"
  add_page "8-bit_AVRs_and_similar_microcontrollers_are_not_OK_anymore"
  add_page "Avoid_std::string"
  add_page "Error_Handling_in_General_and_C%2B%2B_Exceptions_in_Particular"
  add_page "Hardware_Design_Ramblings"
  add_page "Donating_your_idle_computer_time_to_a_good_cause"
  add_page "Hacking_with_the_Arduino_Due"
  add_page "Deine_Privatsph%C3%A4re_in_der_Praxis"
  add_page "Wie_man_Mitgliedsbeitr%C3%A4ge_eines_Vereins_oder_einer_politischen_Partei_von_der_Steuer_absetzt"
  add_page "Tourismus_in_der_N%C3%A4he_von_K%C3%B6ln_und_D%C3%BCsseldorf"
  add_page "Laptop_Kaufkriterien"
  add_page "Navi_Kaufkriterien"
  add_page "Handy_Kaufkriterien"
  add_page "Fernseher_Kaufkriterien"
  add_page "Adler-32_checksum_in_AVR_Assembler"
  add_page "Microsoft_Outlook:_Automatically_add_an_%22(Attachment_deleted:_filename.ext)%22_note_when_removing_e-mail_attachments"
  add_page "Linux_Ramblings"
  add_page "Serial_Port_Tips_for_Linux"
  add_page "Linux_zram"
  add_page "Today%27s_Operating_Systems_are_still_incredibly_brittle"
  add_page "Buying_a_light_bulb_used_to_be_easy"
  add_page "Upgrading_emacs"
  add_page "Apple_Ger%C3%A4te_haben_in_einem_Hackerspace_nichts_zu_suchen"
}


abort ()
{
  echo >&2 && echo "Error in script \"$0\": $*" >&2
  exit 1
}


add_page_url ()
{
  PAGE_ARRAY+=( "$1" "$2" )
}


declare -a PAGE_ARRAY=()

add_page ()
{
  add_page_url "$1" "$PREFIX$1"
}


download_url ()
{
  FILENAME="$1"
  URL="$2"

  CMD="$CURL_TOOL_NAME"
  CMD+=" \"$URL\""
  CMD+=" --progress-bar"  # We don't need a progress bar, but the only alternative is --silent,
                          # which also suppresses any eventual error messages.
  CMD+=" --insecure"  # Do not worry if the remote SSL site cannot be trusted because the corresponding CA certificates are not installed.
  CMD+=" --output \"$FILENAME\""

  echo "$CMD"
  eval "$CMD"
}


download_page ()
{
  PAGE_FILENAME="$1"
  PAGE_URL="$2"

  # Sanitize the filename.
  PAGE_FILENAME="${PAGE_FILENAME//[ \/()$+&\.\-\'\,]/_}"
  PAGE_FILENAME="$TARGET_DIR/$PAGE_FILENAME"

  # You can export the pages as MediaWiki XML or RDF, see pages "Special:Export" and "Special:ExportRDF".
  # However, I could not get those pages to work properly on my current server.

  download_url "$PAGE_FILENAME.wiki-view.html"    "${PAGE_URL}&action=view"
  download_url "$PAGE_FILENAME.content-only.html" "${PAGE_URL}&action=render"
  download_url "$PAGE_FILENAME.printable.html"    "${PAGE_URL}&printable=yes"
  download_url "$PAGE_FILENAME.wiki-markup.txt"   "${PAGE_URL}&action=raw"
}


if [ $# -ne 1 ]; then
  abort "Invalid number of command-line arguments. See this script's source code for more information."
fi

TARGET_DIR="$1"

CURL_TOOL_NAME="curl"

if ! type "$CURL_TOOL_NAME" >/dev/null 2>&1 ;
then
  abort "Tool \"$CURL_TOOL_NAME\" is not installed on this system."
fi

place_your_own_urls_here

declare -i PAGE_ARRAY_ELEM_COUNT="${#PAGE_ARRAY[@]}"
declare -i PAGE_ELEM_COUNT=2
declare -i FILE_COUNT="$(( PAGE_ARRAY_ELEM_COUNT / PAGE_ELEM_COUNT ))"

for ((i=0; i<$PAGE_ARRAY_ELEM_COUNT; i+=$PAGE_ELEM_COUNT)); do

  PAGE_FILENAME="${PAGE_ARRAY[$i]}"
  PAGE_URL="${PAGE_ARRAY[$((i+1))]}"

  download_page "$PAGE_FILENAME" "$PAGE_URL"

done

echo "Success backing up $FILE_COUNT wiki pages."
