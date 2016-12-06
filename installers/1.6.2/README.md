# Spark 1.6.2 Installation

To install Spark 1.6.2, execute `install-spark1.6.2.ps1` in a Powershell prompt with Administrator permissions.

This will install the following into these directories by default:

* JDK8, if not found. Installed by [Chocolatey](https://chocolatey.org/)
* Spark to `C:\Spark\spark-1.6.2-bin-hadoop2.6`
* Hadoop Windows support binaries to `C:\Hadoop\hadoop-2.6.5\`
* Mobius to `C:\Mobius\C:\Mobius\spark-clr-1.6.2`

To connect to a local Spark cluster via Mobius, you can execute the following command:

```
C:\Mobius\C:\Mobius\spark-clr-1.6.2\spark-shell.cmd
```