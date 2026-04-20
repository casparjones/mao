# mao completions for fish
# https://github.com/casparjones/mao

complete -c mao -f

# Sub-commands (only when we haven't seen one yet)
complete -c mao -n __fish_use_subcommand -a update     -d 'Update system + AUR'
complete -c mao -n __fish_use_subcommand -a update-db  -d 'Refresh package database'
complete -c mao -n __fish_use_subcommand -a install    -d 'Install package(s)'
complete -c mao -n __fish_use_subcommand -a remove     -d 'Remove pkg + deps + configs'
complete -c mao -n __fish_use_subcommand -a search     -d 'Search repos and AUR'
complete -c mao -n __fish_use_subcommand -a info       -d 'Show package details'
complete -c mao -n __fish_use_subcommand -a list       -d 'Explicitly installed packages'
complete -c mao -n __fish_use_subcommand -a list-all   -d 'All installed packages'
complete -c mao -n __fish_use_subcommand -a owns       -d 'Which package owns a file'
complete -c mao -n __fish_use_subcommand -a files      -d 'Files belonging to a package'
complete -c mao -n __fish_use_subcommand -a orphans    -d 'List orphaned packages'
complete -c mao -n __fish_use_subcommand -a clean      -d 'Clean package cache'
complete -c mao -n __fish_use_subcommand -a clean-all  -d 'Empty package cache'
complete -c mao -n __fish_use_subcommand -a autoremove -d 'Remove orphaned packages'
complete -c mao -n __fish_use_subcommand -a outdated   -d 'Show available updates'
complete -c mao -n __fish_use_subcommand -a help       -d 'Show help'
complete -c mao -n __fish_use_subcommand -a version    -d 'Show mao & paru version'

# After install/info: all available packages
complete -c mao -n '__fish_seen_subcommand_from install info' \
         -a '(pacman -Slq 2>/dev/null)' -d 'package'

# After remove/files: installed packages only
complete -c mao -n '__fish_seen_subcommand_from remove files' \
         -a '(pacman -Qq 2>/dev/null)' -d 'installed'

# After owns: complete files
complete -c mao -n '__fish_seen_subcommand_from owns' -F

# autoremove option
complete -c mao -n '__fish_seen_subcommand_from autoremove' \
         -l no-info -d 'Skip the orphan preview'
