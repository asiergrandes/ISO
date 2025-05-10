#!/usr/bin/bash
function empaquetaycomprimeFicherosProyecto()
{
  cd /home/$USER/formulariocitas
  tar cvzf  /home/$USER/formulariocitas.tar.gz app.py script.sql requirements.txt templates/*
}
function eliminarMySQL()
{
#Para el servicio
sudo service mysql stop
#Elimina los paquetes +ficheros de configuración + datos
sudo apt-get purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
#servidor MySQL se desinstale completamente sin dejar archivos de residuos.
sudo apt-get autoremove
#Limpia la cache
sudo apt-get autoclean
#Para cerciorarnos de que queda todo limpio:
#Eliminar los directorios de datos de MySQL:
sudo rm -rf /var/lib/mysql
#Eliminar los archivos de configuración de MySQL:
sudo rm -rf /etc/mysql/
#Eliminar los logs
sudo rm -rf /var/log/mysql
}

function crearNuevaUbicacion()
{
    if [ -d /var/www/formulario ]
    then
        echo -e "Borrando el contenido del direcctorio...\n"
        sudo rm -rf /var/www/formulariocitas
        echo "Creando directorio..."
        sudo mkdir -p /var/www/formulariocitas
        echo "Cambiando permisos del directorio..."
        sudo chown -R $USER:$USER /var/www/formulariocitas
        echo ""
        read -p "PULSA ENTER PARA CONTINUAR..."
    else
        echo "Creando directorio..."
        sudo mkdir -p /var/www/formulariocitas
        echo "Cambiando permisos del directorio..."
        sudo chown -R $USER:$USER /var/www/formulariocitas
        echo ""
        read -p "PULSA ENTER PARA CONTINUAR..."
    fi
}

function copiarFicherosProyectoNuevaUbicacion(){
	if test -e "/home/$USER/formulariocitas.tar.gz"; then
		cd /var/www/formulariocitas
		tar xvzf /home/$USER/formulariocitas.tar.gz
	else
		echo "no existe el fichero"
	fi
}
function instalarMySQL(){
	echo "instalando..."
	sudo apt update
	sudo apt install mysql-server	
	SQLStart
}
function SQLStart(){
	aux=$(sudo systemctl status mysql | grep "active")
	if [ -z "$aux" ]; then
		echo "activando ..."
		sudo /etc/init.d/mysql start
		#sudo service mysql start
		#sudo systemctl start mysql
		echo "mysql esta en marcha"
		sleep 1
	else
		echo "mysql ya estaba activado"
	fi 
}
function crear_usuario_basededatos(){
	# Crear el script SQL
	echo "CREATE USER '$USER'@'localhost' IDENTIFIED BY '$USER';" > $HOME/crearusuariobd.sql
	echo "GRANT CREATE, ALTER, DROP, INSERT, UPDATE, INDEX, DELETE, SELECT, REFERENCES, RELOAD on *.* TO '$USER'@'localhost' WITH GRANT OPTION;" >> $HOME/crearusuariobd.sql
	echo "FLUSH PRIVILEGES;" >> $HOME/crearusuariobd.sql
	sudo mysql < $HOME/crearusuariobd.sql
	
	echo "Script SQL creado correctamente en $HOME/crearusuariobd.sql"
}
function crearbasededatos(){
	sudo mysql < /var/www/formulariocitas/script.sql
	echo "Base de datos creada"

}
function ejecutarEntornoVirtual(){
	echo "instalando-pip..."
	
	sudo apt-get update
	sudo apt install -y python3-pip
	sudo apt install python3-dev build-essential libssl-dev libffi-dev python3-setuptools
	sudo apt install python3-venv
	cd /var/www/formulariocitas
	python3 -m venv venv
	#Activar entorno virtual
	source venv/bin/activate
}
function instalarLibreriasEntornoVirtual(){
	pip install --upgrade pip
	pip install -r /var/www/formulariocitas/requirements.txt
}

function probandotodoconservidordedesarrollodeflask(){
	python3 /var/www/formulariocitas/app.py
	#Running on http://127.0.0.1:5000
}

function instalarNGINX(){
	if ! command -v nginx &> /dev/null
    	then
        	sudo apt update
        	sudo apt install -y nginx

        	if [ $? -eq 0 ]
        	then
         		echo "NGINX se ha instalado correctamente."
        	else
            		echo "Error al instalar NGINX. Por favor, verifica la conexión a internet y vuelve a intentarlo."
            		exit 1
        	fi
    	else
        	echo "NGINX ya está instalado en el sistema."
   	fi
}

function ArrancarNGINX(){
	if ! systemctl is-active --quiet nginx
	then
        	sudo systemctl start nginx
        	if [ $? -eq 0 ]
        	then
        		echo "El servicio NGINX se ha iniciado correctamente."
	        else
           		echo "Error al iniciar el servicio NGINX."
    			exit 1
        	fi
    	else
        	echo "El servicio NGINX ya está en marcha."
    	fi
}

function TestearPuertosNGINX(){
	echo "El comando netstat no está disponible. Vamos a instalar el paquete net-tools."
	sudo apt install net-tools
    	
	echo "Puertos escuchando por NGINX:"
    	sudo netstat -ptuln | grep nginx
    	
}

function visualizarIndex(){
    	if ! command -v google-chrome &> /dev/null; then
        	echo "Google Chrome no está instalado. Instalando Google Chrome..."
        	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        	sudo dpkg -i google-chrome-stable_current_amd64.deb
        	sudo apt-get install -f
        	rm google-chrome-stable_current_amd64.deb
    	fi
	source /var/www/formulariocitas/venv/bin/activate
    	google-chrome http://localhost || google-chrome http://127.0.0.1

}
function personalizarIndex(){
	sudo cp -i /home/$USER/index.html /var/www/html/index.nginx-debian.html
	sudo chmod -R 755 /var/www/html
	sudo systemctl restart nginx
	
	echo "Se ha cambiado el indice predeterminado al deseado"
	
	google-chrome http://localhost || google-chrome http://127.0.0.1
}

function instalarGunicorn(){
	if ! command -v gunicorn &> /dev/null; then
	        # Si Gunicorn no está instalado, instalarlo en el entorno virtual
                echo "Gunicorn no está instalado. Instalando Gunicorn..."
                cd /var/www/formulariocitas
		source venv/bin/activate

       		pip install gunicorn 
        	echo "Gunicorn instalado correctamente."
    	else
        	echo "Gunicorn ya está instalado."
    	fi
}

function configurarGunicorn(){

	
  	echo "from app import app" > wsgi.py
    	echo "if __name__ == \"__main__\":" >> wsgi.py  #los >> son para no sobre escribir lo que ya esta escrito
    	echo "   app.run()" >> wsgi.py
    
 	echo "Archivo wsgi.py creado correctamente."
 	
 	echo "Verificando si Gunicorn puede servir la aplicación..."
 	if sudo lsof -i :5000 | grep '.' #solo entra a este if si sudo lsof -i :5000 muestra alguna linea
 	then
		echo "Por favor limpia los puertos en uso con kill -9 PIDs"
	else
 		cd /var/www/formulariocitas
 		source venv/bin/activate
   		gunicorn --bind 127.0.0.1:5000 wsgi:app 
   	fi
   	
   	#si hay algun puerto en uso quitalo con los siguientes metodos:
   	#sudo lsof -i :5000  (5000 en este caso)
   	#sudo kill -9 "PIDs de los puertos"

}

function pasarPropiedadyPermisos(){
   	# Establecer la propiedad al usuario y grupo www-data para todos los archivos y carpetas bajo /var/www
    	sudo chown -R www-data:www-data /var/www/formulariocitas
	sudo chmod -R 755 /var/www/formulariocitas

    	echo "Se han establecido correctamente la propiedad y permisos en /var/www."
}

function crearServicioSystemdFormularioCitas(){
	sudo cp /home/$USER/formulariocitas.service /etc/systemd/system
	echo "Se ha cambiado el directorio del archivo"
	
	sudo systemctl daemon-reload
	sudo systemctl start formulariocitas.service
	sudo systemctl enable formulariocitas.service
	sudo systemctl status formulariocitas.service
}

function configurarNginxProxyInverso(){
	sudo cp /home/$USER/formulariocitas.conf /etc/nginx/conf.d
	echo "Se ha cambiado el directorio del archivo"
	
	sudo nginx -t
	
	#-t es una opción que se utiliza para realizar una prueba de sintaxis en la configuración de Nginx. 
}

function cargarFicherosConfiguracionNginx(){
	sudo systemctl reload nginx
	echo "Se han cargado los nuevos cambios en la configuracion"
}

function rearrancarNginx(){
	sudo systemctl restart nginx
	echo "Se ha reiniciado el demonio NGNIX"
}

function testearVirtualHost(){
	google-chrome http://localhost:8080 
}

function verNginxLogs(){
	sudo tail -10 /var/log/nginx/error.log
}

function copiarServidorRemoto(){
	# Para que este metodo funcione hace falta instalar el openssh-server, iniciarlo y habilitarlo
	# Sudo ufw allow ssh en el servidor remoto para que el firewall remoto de acceso al servidor propio
	# Verificar si el servicio SSH está instalado
	
    	if ! dpkg -s openssh-server &> /dev/null; then
        	echo "Instalando el servicio SSH..."
        	sudo apt-get update
        	sudo apt-get install openssh-server -y
    	fi

        sudo systemctl start ssh
        echo "Se ha arrancado el demonio"

   	 # Solicitar la dirección IP del servidor remoto
    	read -p "Introduce la dirección IP del servidor remoto: " ip

    	# Copiar los archivos al servidor remoto
    	echo "Copiando archivos al servidor remoto..."
    	scp /home/$USER/formulariocitas.tar.gz $USER@$ip:/home/$USER@$ip
    	scp /home/$USER/menu.sh $USER@$ip:/home/$USER@$ip
    	
    	echo "ejecuta la opcion de salida y ejecuta lo siguiente:"
    	echo "ssh $USER@$ip"
    	echo "bash -x menu.sh"
    	echo "Entra en el siguiente link http://$ip:8080"
    	# siendo $ip la dirección remota

}

function controlarIntentosConexionSSH(){
    	# Definimos las variables para contar los intentos
    	intentos_fallidos=0
    	intentos_exitosos=0

   	# Copiar el contenido de /var/log/auth.log a un archivo temporal
   	cat /var/log/auth.log  > auth.log.txt
	less auth.log.txt | tr -s ' ' '@' > auth.log.lineaporlinea.txt
	
	fallo="Failed@password"
	acierto="Accepted@password"

    	# Procesar el archivo temporal para contar los intentos fallidos
    	for lineaF in `less auth.log.lineaporlinea.txt | grep $fallo` 
    	do
        	((intentos_fallidos++))
    	done
    
    	# Procesar el archivo temporal para contar los intentos exitosos
    	for lineaA in `less auth.log.lineaporlinea.txt | grep $acierto` 
    	do
    	    	((intentos_exitosos++))
    	done

    	# Mostramos la información por pantalla
    	echo "Intentos de conexión SSH:"
    	echo "  - Fallidos: $intentos_fallidos"
    	echo "  - Exitosos: $intentos_exitosos"

    	# Eliminar los archivos temporales
    	rm auth.log.txt auth.log.lineaporlinea.txt
}


function salirMenu(){
	echo "Fin del Programa"
}

### Main ###
opcionmenuppal=0
while test $opcionmenuppal -ne 26
do
    #Muestra el menu
    echo -e " \n"
    echo -e "0 Empaqueta y comprime los ficheros clave del proyecto\n"
    echo -e "1 Eliminar la instalación de mysql\n"
    echo -e "2 Crear la nueva ubicación \n"
    echo -e "3 Copiar Ficheros del Proyecto en la nueva ubicación\n"
    echo -e "4 Instalar y arranca mySQL\n"
    echo -e "5 Crear Usuario en la Base de Datos\n"
    echo -e "6 Crear base de datos invitados y tabla clientes\n"
    echo -e "7 Ejecutar entorno virtual\n"
    echo -e "8 Instalar librerias en el entorno virtual\n"
    echo -e "9 Probando todo con servidor de desarrollo de flask\n"
    echo -e "10 Instalar NGINX\n"
    echo -e "11 Arrancar NGINX\n"
    echo -e "12 Testear puertos NGINX\n"
    echo -e "13 Visualizar el indice\n"
    echo -e "14 Personalizar el indice\n"
    echo -e "15 Instalar Gunicorn\n"
    echo -e "16 Configurar Gunicorn el indice\n"
    echo -e "17 Pasar Propiedas y Permisos\n"
    echo -e "18 Crear el Servicio de FormularioCitas\n"
    echo -e "19 Configurar Nginx como proxy inverso\n"
    echo -e "20 Cargar los nuevos cambios de la configuración\n"
    echo -e "21 Rearrancar el demonio Nginx\n"
    echo -e "22 Testear Virtual Host\n"
    echo -e "23 Ver NGINX logs\n"
    echo -e "24 Copiar al Servidor Remoto\n"
    echo -e "25 Controlar los intentos de Conexion de SSH\n"
    echo -e "26 salir del Menu \n"
    	read -p "Elige una opcion:" opcionmenuppal
    echo -e " \n"
    case $opcionmenuppal in
        	0) empaquetaycomprimeFicherosProyecto;;
        	1) eliminarMySQL;;
        	2) crearNuevaUbicacion;;
        	3) copiarFicherosProyectoNuevaUbicacion;;
        	4) instalarMySQL;;
        	5) crear_usuario_basededatos;;
        	6) crearbasededatos;;
        	7) ejecutarEntornoVirtual;;
        	8) instalarLibreriasEntornoVirtual;;
        	9) probandotodoconservidordedesarrollodeflask;;
        	10) instalarNGINX;;
        	11) ArrancarNGINX;;
        	12) TestearPuertosNGINX;;
        	13) visualizarIndex;;
        	14) personalizarIndex;;
        	15) instalarGunicorn;;
        	16) configurarGunicorn;;
        	17) pasarPropiedadyPermisos;;
        	18) crearServicioSystemdFormularioCitas;; 
        	19) configurarNginxProxyInverso;;
        	20) cargarFicherosConfiguracionNginx;;  
        	21) rearrancarNginx;;   
        	22) testearVirtualHost;;  
        	23) verNginxLogs;;	
        	24) copiarServidorRemoto;;
        	25) controlarIntentosConexionSSH;;
        	26) salirMenu;;
   	 *) ;;
    esac
done

exit 0


