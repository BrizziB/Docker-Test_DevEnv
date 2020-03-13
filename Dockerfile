# WildFly 16.0.0.Final with OpenJDK 1.7 OS/ARCH linux/amd64

FROM jboss/wildfly:16.0.0.Final

LABEL mantainer="Boris Brizzi boris.brizzi@gmail.com" 

# Definizione delle variabili globali - per pulizia visiva
# for Appserver 
# Credentials
ENV WILDFLY_USER admin
ENV WILDFLY_PASS password
# Utility
ENV JBOSS_CLI /opt/jboss/wildfly/bin/jboss-cli.sh
ENV DEPLOYMENT_DIR /opt/jboss/wildfly/standalone/deployments/

# for Database
# Qui si pre-impostano quelli che saranno i parametri (fra cui la versione) del DB a cui ci si vuole collegare
# E' un po' brutto doverlo specificare a questo livello ma pare inevitabile, visto il seguito
ENV DB_NAME sample
ENV DB_USER mysql
ENV DB_PASS mysql
ENV DB_URI db:3306
ENV MYSQL_VERSION 5.1.25


# Setup della console Wildfly, si impostano le credenziali
RUN echo "Building stlab/wildfly16"
RUN echo "=> Adding administrator user"
RUN $JBOSS_HOME/bin/add-user.sh -u $WILDFLY_USER -p $WILDFLY_PASS --silent

# Configurazione di Wildfly, una volta attivato si usa il JbossCLI
# per aggiungere i settaggi necessari ad eseguire l'applicazione che sarà deployata
# Le azioni sono spiegate negli "echo"
RUN echo "=> Starting WildFly server" && \
      bash -c '$JBOSS_HOME/bin/standalone.sh &' && \
    echo "=> Waiting for the server to boot" && \
      bash -c 'until `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null | grep -q running`; do echo `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null`; sleep 1; done' && \
    echo "=> Downloading MySQL driver" && \
      curl --location --output /tmp/mysql-connector-java-${MYSQL_VERSION}.jar --url http://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/${MYSQL_VERSION}/mysql-connector-java-${MYSQL_VERSION}.jar && \
    echo "=> Adding MySQL module" && \
      $JBOSS_CLI --connect --command="module add --name=com.mysql --resources=/tmp/mysql-connector-java-${MYSQL_VERSION}.jar --dependencies=javax.api,javax.transaction.api" && \
    echo "=> Adding MySQL driver" && \
      $JBOSS_CLI --connect --command="/subsystem=datasources/jdbc-driver=mysql:add(driver-name=mysql,driver-module-name=com.mysql)" && \
    echo "=> Adding main Datasource" && \
      $JBOSS_CLI --connect --command="data-source add \
        --name=${DB_NAME}DS \
        --jndi-name=java:/jdbc/datasources/${DB_NAME}DS \
        --user-name=${DB_USER} \
        --password=${DB_PASS} \
        --driver-name=mysql \
        --connection-url=jdbc:mysql://${DB_URI}/${DB_NAME} \
        --use-ccm=false \
        --max-pool-size=25 \
        --blocking-timeout-wait-millis=5000 \
        --enabled=true" && \
    echo "=> Shutting down WildFly and Cleaning up" && \
      $JBOSS_CLI --connect --command=":shutdown" && \
      rm -rf $JBOSS_HOME/standalone/configuration/standalone_xml_history/ $JBOSS_HOME/standalone/log/* && \
      rm -f /tmp/*.jar

# Si espongono le porte tramite cui si può interagire con il contenuto del container
# 8080 per l'applicazione, 9990 è la console admin di Wildfly, 
# 5005 per consentier il Debug da remoto - questa porta andrà indicata nell IDE da cui si intende debuggare l'applicazione
EXPOSE 8080 9990 5005

#echo "=> Restarting WildFly"
# Questo è il comando che sarà eseguito ogni volta che si avvia il container. Tutto ciò che viene prima è eseguito solo in fase di inizializzazione
# Quello che si fa è avviare Wildfly in modalità standalone ed aprire le interfacce per accedere ad applicazione, pagina admin del server, e debug
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0", "--debug", "*:5005"]
