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

Usage: /usr/bin/ros-upgrade [-u <username>] [-p <password>] [-P <ssh-port>] -v[<version>] hostname1 [hostname2] [hostname3]
options:
   -u username   Provide username as argument (default "admin")
   -p password   Provide password as argument (security unwise)
   -P ssh-port   Provide ssh service port (default 22)
   -v version    RouterOS version to upgrade 
      hostname   Hostname list, list for multiple hostname
   -h            Print this Help.
```
<p align="right">(<a href="#readme-top">back to top</a>)</p>
