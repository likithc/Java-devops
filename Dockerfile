# ==========================================
# STAGE 1: The Builder (The Workshop)
# ==========================================
FROM maven:3.9.4-eclipse-temurin-17 AS builder

# Set the working directory inside the container
WORKDIR /app

# Copy only the pom.xml first to download dependencies
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy the actual source code and build the application
COPY src ./src
RUN mvn clean package -DskipTests

# ==========================================
# STAGE 2: The Runner (The Living Room)
# ==========================================
FROM eclipse-temurin:17-jre-alpine

# Set the working directory for the final image
WORKDIR /app

# Steal the compiled .jar file from the 'builder' stage
COPY --from=builder /app/target/*.jar app.jar

# Tell Docker what port the app uses
EXPOSE 8080

# The command to start the application
ENTRYPOINT ["java", "-jar", "app.jar"]
