FROM maven:3.9-eclipse-temurin-21

WORKDIR /app

# dependências em camada própria: mudar uma classe não baixa tudo de novo
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q compile dependency:copy-dependencies -DoutputDirectory=target/dependency

CMD ["java", "-cp", "target/classes:target/dependency/*", "br.edu.despensa.DespensaApp"]
