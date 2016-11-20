touch ./install-vars

setvar () {
    grep -v "^$1=" ./install-vars > ./install-vars.new && mv ./install-vars.new ./install-vars
    echo "$1=$2" >> ./install-vars
}

getvar () {
    value=$(grep "^$1=" ./install-vars | tail -n 1 | sed "s/^$1=//")
}
