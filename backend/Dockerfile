FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -B -ntp -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN groupadd -r vms && useradd -r -g vms vms
COPY --from=build --chown=vms:vms /build/target/*.jar app.jar
USER vms
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
