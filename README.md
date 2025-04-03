<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
  </ol>
</details>

<!-- GETTING STARTED -->
## Getting Started

This project build base on issue that The Dude v7 can upgrade package. 
with erroe "needed packages are not available"

### Prerequisites

This script use the software and how to install them.
* sshpass
  ```sh
  apt-get install sshpass
  ```
<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
## Usage
```sh
  Upgrade RouterOS using remote command

    Usage: ./ros-upgrade -f <filename> [options]
       or: ./ros-upgrade [-u <username>] [-p <password>] [-P <ssh-port>] [-r <repo-url>] [-v <version>] [-R <yes/no>]
           hostname1 [hostname2] [hostname3]

  Options:
      -f filename   File containing list of hosts (format: IP Description)
      -u username   SSH username (default: admin)
      -p password   SSH password
      -P port       SSH port (default: 22)
      -r repo-url   Repository URL (default: https://download.mikrotik.com/routeros)
      -v version    RouterOS target version (default: 7.18.2)
      -R [yes/no]    Auto reboot after upgrade (default: no, use -R alone for yes)
      -a packages   Additional packages to install (comma-separated)
      -h            Show this help message
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>
