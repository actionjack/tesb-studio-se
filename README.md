# Talend Open Studio for ESB
http://www.talend.com


![alt text](http://www.talend.com/sites/default/files/logo-talend.jpg "Talend")


> Contents

This repository contains the source files for Talend Open Studio for ESB.


## Repository Structure
All Talend Studio repositories follow the same file structure:
```

  |_ main          Main Eclipse plugins and features
    |_ features
    |_ plugins
  |_ test          Eclipse plugins and features for unit tests. 
      |_ features
      |_ plugins
  |_ i18n          Internationalization plugins and features.
      |_ features
      |_ plugins
```

## How to build projects

### Option 1: Docker Build (Recommended)

The easiest way to build this project is using Docker, which handles all dependencies automatically:

```bash
# Build the Docker image
docker build -t tesb-studio-se:maven .

# View build results
docker run --rm tesb-studio-se:maven

# Or use docker-compose
docker-compose build maven-build
docker-compose run maven-build
```

This downloads 69 runtime JARs (CXF, Camel, Spring, ActiveMQ) to the plugin `lib/` directories.

> **Note:** See [BUILD_NOTES.md](BUILD_NOTES.md) for detailed documentation and [docs/build-architecture.md](docs/build-architecture.md) for architecture diagrams.

### Option 2: Traditional Build (Requires Target Platform)

If you have a full Talend Open Studio installation, use Maven with the target platform:

```bash
mvn clean install -Dtycho.targetPlatform=<path_to_tos>
```

For example:
```bash
mvn clean install -Dtycho.targetPlatform=d:/TOS/TOS_ESB-r77287-V5.1.0NB
```

## Validating Build Artifacts

Verify the downloaded JARs are valid and usable:

```bash
# Build and run validation
docker build -f Dockerfile.validate -t tesb-studio-se:validate .
docker run --rm tesb-studio-se:validate
```

This performs:
- Archive integrity checks (100% pass expected)
- Manifest inspection (version, OSGi metadata)
- Class loading smoke test (CXF, Camel, Spring)
- Version consistency analysis

Expected results: 69 JARs, 100% integrity, 19/21 classes load successfully.

## Download

You can download this product from the [Talend website](http://www.talend.com/download/esb).


## Usage and Documentation

Documentation is available on [Talend Help Center](http://help.talend.com/).



## Support 

You can ask for help on our [Forum](http://www.talend.com/services/global-technical-support).


## Contributing

We welcome contributions of all kinds from anyone.

Using the bug tracker [Talend bugtracker](http://jira.talendforge.org/) is the best channel for bug reports, feature requests and submitting pull requests.

Feel free to share your Talend components on [Talend Exchange](http://www.talendforge.org/exchange).

## License

Copyright (c) 2006-2014 Talend

Licensed under the LGPLv3 License
