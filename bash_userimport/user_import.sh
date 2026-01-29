#!/usr/bin/bash

CSV_FILE="userlist.csv"

ERRORS=""

# Must be run as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# Read in the file and strip off the header row.
tail -n +2 $CSV_FILE | while IFS="," read -r username fullname password phone email
do
    # Process the current line/user
    useradd -m -s /bin/bash -c "$fullname, $phone, $email" "$username"

    if [[ $? -ne 0 ]]; then
        echo "Failed to create user $username"
        ERRORS="FAILED: $username"
        continue
    fi

    echo "$username:$password" | chpasswd

    chage -d 0 "$username"

    echo "User Created: $username"


# End of the loop
done

echo "Finished! ✅🎉"
echo $ERRORS

