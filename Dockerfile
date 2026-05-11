# ── Stage 1: Build ─────────────────────────────────────────────
# Use the official Maven image with Java 17 to compile the project
FROM maven:3.9-eclipse-temurin-17 AS builder
 
# Set working directory inside the container
WORKDIR /app
 
# Copy pom.xml first — Docker will cache this layer so Maven
# dependencies are NOT re-downloaded on every code change
COPY pom.xml .
RUN mvn dependency:go-offline -B
 
# Now copy all source code and build the JAR
COPY src ./src
RUN mvn clean package -DskipTests -B
 
# ── Stage 2: Runtime ────────────────────────────────────────────
# Use a slim JRE-only image — much smaller than the build image
FROM eclipse-temurin:17-jre-alpine
 
WORKDIR /app
 
# Copy only the built JAR from the builder stage
COPY --from=builder /app/target/FoodFrenzy-0.0.1-SNAPSHOT.jar app.jar
 
# Expose the port Spring Boot listens on
EXPOSE 8083
 
# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
