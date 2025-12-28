install_sysext_community() {
  SYSEXT="${1}"
  URL="https://extensions.fcos.fr/community"
  sudo install -d -m 0755 -o 0 -g 0 /etc/sysupdate.${SYSEXT}.d
  sudo restorecon -RFv /etc/sysupdate.${SYSEXT}.d
  curl --silent --fail --location "${URL}/${SYSEXT}.conf" \
    | sudo tee "/etc/sysupdate.${SYSEXT}.d/${SYSEXT}.conf"
  sudo /usr/lib/systemd/systemd-sysupdate update --component "${SYSEXT}"
}

update_sysext() {
  SYSEXT="${1}"
  sudo /usr/lib/systemd/systemd-sysupdate update --component ${SYSEXT}
  sudo systemctl restart systemd-sysext.service
  systemd-sysext status
}

update_sysext_all() {
  for c in $(/usr/lib/systemd/systemd-sysupdate components --json=short | jq --raw-output '.components[]'); do
    sudo /usr/lib/systemd/systemd-sysupdate update --component "${c}"
  done
  sudo systemctl restart systemd-sysext.service
  systemd-sysext status
}