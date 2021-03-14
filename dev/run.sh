
if [[ ! -f "./bin/bbds" || "$1" == "build" ]]; then
    mkdir -p ./bin
    dart2native ./bbds_cli/lib/main.dart -o ./bin/bbds
fi
./bin/bbds $@