# spark-installer-windows
Versioned Apache Spark installation scripts for Windows.

## Why does this exist?
Great question. This exists because... Well... Look at the amount of stuff you have to do in order to get Spark running properly on Windows (from the [Mobius for Spark](https://github.com/Microsoft/Mobius/) project):

| |Version | Environment variables |Notes |
|---|----|-----------------------------------------------------|------|
|JDK |7u85 or 8u60 ([OpenJDK](http://www.azul.com/downloads/zulu/zulu-windows/) or [Oracle JDK](http://www.oracle.com/technetwork/java/javase/downloads/index.html)) |JAVA_HOME | After setting JAVA_HOME, run `set PATH=%PATH%;%JAVA_HOME%\bin` to add java to PATH |
|Spark | [1.5.2 or 1.6.*](http://spark.apache.org/downloads.html) | SPARK_HOME |Spark can be downloaded from Spark download website. The version of Spark should match the one supported by the Mobius branch/release you are using. See [Mobius versioning policy](./mobius-release-info.md#versioning-policy) for notes of Spark & Mobius versions. Alternatively, if you used [`RunSamples.cmd`](../csharp/Samples/Microsoft.Spark.CSharp/samplesusage.md) to run Mobius samples, you can find `toos\spark*` directory (under [`build`](../build) directory) that can be used as SPARK_HOME  |
|winutils.exe | see [Running Hadoop on Windows](https://wiki.apache.org/hadoop/WindowsProblems) for details |HADOOP_HOME |Spark in Windows needs this utility in `%HADOOP_HOME%\bin` directory. It can be copied over from any Hadoop distribution. Alternative, if you used [`RunSamples.cmd`](../csharp/Samples/Microsoft.Spark.CSharp/samplesusage.md) to run Mobius samples, you can find `toos\winutils` directory (under [`build`](../build) directory) that can be used as HADOOP_HOME  |
|Mobius | Appropriate version of [Mobius release](https://github.com/Microsoft/Mobius/releases) or a valid dev build | SPARKCLR_HOME |If you downloaded a [Mobius release](https://github.com/Microsoft/Mobius/releases), SPARKCLR_HOME should be set to the directory named `runtime` (for example, `D:\downloads\spark-clr_2.10-1.5.200\runtime`). Alternatively, if you used [`RunSamples.cmd`](../csharp/Samples/Microsoft.Spark.CSharp/samplesusage.md) to run Mobius samples, you can find `runtime` directory (under [`build`](../build) directory) that can be used as SPARKCLR_HOME. |

Good luck finding all of the right versions, configuring them to work correctly together, and setting all of the right environment variables on your own.

This project exists to provide an out-of-the-box experience for multiple versions of Spark, Mobius, Hadoop, et al that just work on Windows.

## Third Party Acknowledgements
This project wouldn't be possible without Microsoft and the great team who works on [Mobius for Spark](https://github.com/Microsoft/Mobius). Much of our installation scripts are based upon the work they did for Mobius' build chain.

[Chocolatey](https://chocolatey.org/) has also been a major help and we will likely be converting these scripts into Chocolatey commands in the near future.