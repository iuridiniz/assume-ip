# Assume-IP

## Description

**Assume-IP** is a Bash script and systemd service for monitoring a specific MAC address on a local network and managing an associated IP address on a given network interface. It is designed for scenarios where you want to automatically add or remove an IP address from your server based on the presence of another device (identified by its MAC address) on the network.

## Installation Instructions

### Dependencies

- `bash`
- `arp-scan`
- `iproute2` (for the `ip` command)
- `systemd` (for service integration, optional)

### Install `arp-scan`

On Debian/Ubuntu:
```sh
sudo apt-get install arp-scan
```

On Fedora/RHEL/CentOS:
```sh
sudo dnf install arp-scan
```

### Setup

1. Clone or copy the repository files to your server.
2. Edit `assume_ip.env` (or `/etc/default/assume_ip`) to set your target MAC, IP, and interface.
3. Make the script executable:
   ```sh
   chmod +x /root/assume_ip.sh
   ```
4. (Optional) Install the systemd service:
   ```sh
   sudo cp assume_ip.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now assume_ip.service
   ```

## Usage Instructions

Run the script as root:

```sh
sudo ./assume_ip.sh [OPTIONS]
```

### Options

- `-m <MAC_ADDRESS>`: Target MAC address to monitor.
- `-i <IP_ADDRESS>`: Target IP address to manage.
- `-n <INTERFACE>`: Network interface to use.
- `-s <SECONDS>`: Scan interval in seconds.
- `--dry-run`: Log actions without making changes.
- `--once`: Run one scan and exit.
- `-q, --quiet`: Suppress non-critical output.
- `--log-level <LEVEL>`: Set minimum logging level (`DEBUG`, `INFO`, `WARN`, `ERROR`).
- `-h, --help`: Show help.

You can also set environment variables: `TARGET_MAC`, `TARGET_IP`, `INTERFACE`, `SCAN_INTERVAL_SECONDS`, `LOG_LEVEL`.

## Contributing

Contributions, bug reports, and feature requests are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgements

- Inspired by network failover and high-availability techniques.
- Uses [arp-scan](https://github.com/royhills/arp-scan).

## Contact Information

Author: Iuri Diniz  
GitHub: [https://github.com/iuridiniz](https://github.com/iuridiniz)  

## Additional Information

- The script must be run as root to manage network interfaces.
- The systemd service expects configuration in `/etc/default/assume_ip`.

## Examples

Monitor for a device and manage an IP:

```sh
sudo ./assume_ip.sh -m 00:11:22:33:44:55 -i 192.168.1.100 -n eth0
```

Run once in dry-run mode:

```sh
sudo TARGET_MAC=AA:BB:CC:DD:EE:FF ./assume_ip.sh --once --dry-run --log-level DEBUG
```

## References

- [arp-scan documentation](https://linux.die.net/man/1/arp-scan)
- [iproute2 documentation](https://man7.org/linux/man-pages/man8/ip.8.html)
- [systemd documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
