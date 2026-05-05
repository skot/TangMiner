ThisBuild / scalaVersion := "2.12.18"

lazy val root = (project in file("."))
  .settings(
    name := "tangminer",
    version := "0.1.0",
    libraryDependencies ++= Seq(
      "com.github.spinalhdl" %% "spinalhdl-core" % "1.10.2",
      "com.github.spinalhdl" %% "spinalhdl-lib" % "1.10.2",
      compilerPlugin("com.github.spinalhdl" %% "spinalhdl-idsl-plugin" % "1.10.2")
    )
  )
