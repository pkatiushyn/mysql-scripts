#########################################################################################################
# Sript to automate some task with DB user creation: addin to Vault and DB, etc                         # 
#########################################################################################################
set -o errexit
set -o pipefail

while getopts u:h:t:d:p: option
do
 case "${option}"
 in
 u) USER=${OPTARG};;
 h) HOST=${OPTARG};;
 t) TITLE=${OPTARG};;
 d) DB=${OPTARG};;
 p) RIGHTS=${OPTARG};;
 esac
done

if [ "$USER" == "" -o "$USER" == "root" -o "$HOST" == "" -o "$TITLE" == "" -o "$DB" == "" -o "$RIGHTS" == "" ]
then
    echo "
Usage:
     -u - user
     -h - host
     -t - title
     -d - database name
     -p - permission to give as in grant statement, for example 'SELECT, UPDATE' or ALL 
Example: ./create_user.sh -u app_user1 -h dbsrv01 -t 'App reader' -d db1 -p 'SELECT, INSERT'";
exit 0
fi

set -o nounset

echo "Trying to connect to dbhost..."
mysql -h $HOST -e"use $DB" && (echo "Success...";)  || (echo "Error connecting to host or database"; exit 1)

echo "Checking, if user already exists..."
mysql -h$HOST -e"show grants for $USER" > /dev/null 2>&1 && (echo "User already exists. Exit."; exit 1)

#VAULTLISTID=999
#VAULTKEY=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Add user to vault and get password
#PASSWORD=$(curl --request POST https://vault/api/passwords \
#       -d "PasswordListID=$VAULTLISTID" \
#       -d "Title=$TITLE" \
#       -d "Username=$USER" \
#       -d "apikey=$VAULTKEY" \
#       -d "Notes"="Host:$HOST" \
#       -d "GeneratePassword=true" | json_pp | grep 'Password"' | cut -d'"' -f4)

echo "Creating user $USER on $HOST:"
echo "CREATE USER $USER IDENTIFIED by '$PASSWORD'; GRANT ${RIGHTS} ON ${DB}.* TO $USER;"
mysql -h$HOST -e"CREATE USER $USER IDENTIFIED by '$PASSWORD'; GRANT ${RIGHTS} ON ${DB}.* TO $USER;SHOW GRANTS FOR $USER;"
echo "Self destructing message to be sent to requester:
host:$HOST
user:$USER
pass:$PASSWORD
db:$DB"


