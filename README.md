# Wkurwiacz Krzycki 9000

A simple script to monitor and display statistics from a specific poll on wroclaw.pl.

## Features

- Real-time statistics monitoring
- Color-coded status indicators
- Simple and clean interface
- Easy to use

## Demo

![Wkurwiacz Krzycki 9000 Demo](https://github.com/rlempa/wkurwiacz-krzycki-9000/raw/main/demo.gif)

The demo shows:
- Script startup with ASCII art logo
- Real-time statistics updates
- Color-coded status changes
- ESC key exit functionality

## Requirements

- Bash shell
- curl (usually pre-installed on macOS and Linux)
- For Windows: Git Bash or WSL

## Installation

### macOS
1. Open Terminal
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/wkurwiacz-krzycki-9000.git
   cd wkurwiacz-krzycki-9000
   ```
3. Make the script executable:
   ```bash
   chmod +x wkurwiacz-krzycki-9000.sh
   ```

### Windows
1. Install Git Bash from [git-scm.com](https://git-scm.com/downloads)
2. Open Git Bash
3. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/wkurwiacz-krzycki-9000.git
   cd wkurwiacz-krzycki-9000
   ```
4. Make the script executable:
   ```bash
   chmod +x wkurwiacz-krzycki-9000.sh
   ```

## Usage

1. Run the script:
   ```bash
   ./wkurwiacz-krzycki-9000.sh
   ```

2. The script will display:
   - Current status (RUNNING in green or WAITING in red)
   - Option 1 count
   - Option 2 count
   - Total count

3. To exit the script:
   - Press the ESC key

## Status Colors

- 🟢 **GREEN**: RUNNING - Script is actively fetching data
- 🔴 **RED**: WAITING - Script encountered an error and is waiting to retry

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Solution: Make sure the script is executable (`chmod +x wkurwiacz-krzycki-9000.sh`)

2. **Command Not Found**
   - Solution: Make sure you're in the correct directory and using the correct path

3. **curl not found**
   - Solution: Install curl using your package manager
     - macOS: `brew install curl`
     - Windows: Usually comes with Git Bash

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This script is for educational purposes only. Use responsibly and in accordance with the website's terms of service.
