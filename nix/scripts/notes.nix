{ pkgs, ... }:

pkgs.writeShellScriptBin "notes" ''
  NOTES_HOME=$HOME/docs

  new_note(){
    IFS= read -p "Note name: " note
    local full_path="''${NOTES_HOME}/''${note}.md"
    full_path=''${full_path// /_} # Replace any space with underscore
    touch ''${full_path}
    echo "# ''${note} \n\n" >> ''${full_path}
    ${pkgs.neovim}/bin/nvim ''${full_path}
  }


  new_daily(){
    local file="$NOTES_HOME/daily.md"
    local tmpl="## Date: $(date +%Y-%m-%d)"
    latest_header=$(sed '3!d' $file)
    if ! [[ $latest_header == $tmpl ]]; then
      sed -i "2s/^/\\n$tmpl\\n\\n\\n/" $file
    fi
    ${pkgs.neovim}/bin/nvim $file +5
  }

  open_daily(){
    local file="$NOTES_HOME/daily.md"
    ${pkgs.neovim}/bin/nvim $file
  }


  print_help() {
      cat <<-EOF
      Handles notes creation and easy access.

      notes [action]

      [actions]
      new                   Creates a new note and puts it in the default location.
      daily                 Opens the daily notes document with a new entry if needed.
      dailyo                Opens the daily note.
      home                  Navigates to the notes home folder.
      find                  Searches through the notes in the notes home folder.
      <empty>               Defaults to find
  EOF
  }

  search() {
    local note=$(find ~/docs -mindepth 1 -type f | ${pkgs.fzf}/bin/fzf --height=50%)
    if [[ $note == "" ]]; then
      return 0
    fi
    ${pkgs.neovim}/bin/nvim $note
  }

  case $1 in
    "new") new_note;;
    "daily") new_daily;;
    "daily") open_daily;;
    "-h") ;& # Fall through to the next case
    "-help") ;& # Fall through to the next case
    "help") print_help;;
    "home") cd $NOTES_HOME;;
    "find") ;& # Fall through to the next case
    *) search;;
  esac
''

