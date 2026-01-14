# customer-api-definitions

This repository contains all API definitions which are useful for our customers. At the moment the plain OpenAPI definitions are
published here and also made available as a Maven artifact.

The generated clients can be downloaded as separate Maven artifacts for each API definition. They are generated for Java 8 and
above.

```xml
<dependency>
    <groupId>com.hlag.api</groupId>
    <artifactId>openapi-specs</artifactId>
    <version>LATEST VERSION HERE</version>
</dependency>
```

## API Definitions

### Rate Sheet Notification API

This API is called by Hapag-Lloyd to notify customers about changes in rate sheets. We generate a client using Spring's
RestTemplate. You can include the generated client in your project using the following Maven dependency:

```xml
<dependency>
    <groupId>com.hlag.api</groupId>
    <artifactId>ratesheet-resttemplate</artifactId>
    <version>LATEST VERSION HERE</version>
</dependency>
```

## Contributing

### Adding an API Definition

To add new API definitions to this repository, please follow these steps:

- add the OpenAPI definition file (YAML or JSON) to the `src/main/openapi` folder. Create a new subfolder if necessary.
- in case a new subfolder was created:
  - update the `pom.xml` to include the new folder as a separate execution of the Open API generator
  - add a new submodule to the parent `pom.xml` file. Copy an existing module definition and adjust the artifactId.

### Generation Process

The code generation process is fully automated using Maven and involves multiple steps:

#### 1. OpenAPI Code Generation

The project uses the [OpenAPI Generator Maven Plugin](https://openapi-generator.tech/) to generate Java client code from OpenAPI specifications:

- **Generator**: `java` with `resttemplate` library
- **Input**: OpenAPI YAML files from `src/main/openapi/` subdirectories
- **Output**: Generated projects in `target/generated-sources/openapi/`
- **Package Structure**:
  - API classes: `com.hlag.api.ratesheet.subscription`
  - Model classes: `com.hlag.api.ratesheet.subscription.model` (with `DTO` suffix)

#### 2. Resource Copying

Maven Resources Plugin handles copying of generated sources and OpenAPI specifications:

- Generated sources are copied to the project root as separate Maven modules
- OpenAPI specs (YAML/JSON files) are copied to the build output directory for packaging

#### 3. Project Structure Setup

A custom build script (`build.sh`) automatically configures the generated Maven submodules:

- Sets up parent-child relationships in POM files using `xmlstarlet`
- Inherits common configuration (groupId, version, SCM, licenses, developers) from parent POM
- Removes redundant elements to maintain clean module structure

#### 4. Module Compilation

The Maven Invoker Plugin compiles all generated submodules:

- Discovers submodules by scanning for `*/pom.xml` files
- Executes `mvn compile` on each submodule
- Provides build reports in `target/invoker-reports/`

#### 5. Packaging

The final step packages all OpenAPI specifications and generated code into a single artifact that can be published to Maven Central
for customer consumption.

## License

All API definitions in this repository are licensed under the [Apache License, Version 2.0](LICENSE).
