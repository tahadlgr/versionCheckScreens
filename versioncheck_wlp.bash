#!/bin/bash
cd /usy/versioncheck
. ./blacklist.bash


>/usy/versioncheck/liberty_all_versions.txt

HOSTS=$(python envanter_wlp.py)


FILE_PATH='/ibm/wlp'
arr1=( $HOSTS )
arr=( $variable )




for HOST in $HOSTS
do
	if [[ ! " ${arr[@]} " =~ " ${HOST} " ]]
	then
		echo -e "*******Islem yapilacak sunucu: $HOST*******"
		
		k=0 ##Sunucular icin dizin varliklarini ayirt etmede kullanilan degisken
		
		##### Java verisi alinana kadar No_java verisi yazdirilir #######
		javaVersion="No_java"
		java_existing_case=0
		
		##### Db2 verisi alinana kadar No_db2 verisi yazdirilir #######
		db2driverVersion="No_db2_connection"
		db2driver_existing_case=0
		
		##### Oracle verisi alinana kadar No_oracle verisi yazdirilir #######
		ojdbcVersion="No_oracle_connection"
		ojdbc_existing_case=0 ## ojdbc check icin atanan degisken
		
		##### Operating system verisi aliniyor #######
		rhel_version=`ssh -q $HOST cat /etc/redhat-release ` && echo -e "Sunucunun isletim sistemi bilgisi alinmistir." || echo -e "$HOST sunucusunda RHEL versiyonu alinamamistir. \n"
		
		ssh -q -o ConnectTimeout=30 $HOST [[ -e $FILE_PATH ]] && echo -e "$HOST sunucusunda $FILE_PATH dizini bulunmaktadir. \n" && k=1 || echo -e "$HOST sunucusunda $FILE_PATH dizini bulunamamistir. Ayrica ssh baglantisini kontrol edebilirsiniz. \n"

		if [ $k -eq 1 ]
		then
			##### Versiyon bilgisi sunucudan aliniyor ######
			version_check4liberty=`ssh -q $HOST basename $FILE_PATH/*.zip`
				
			##### Alinan versiyon bilgisi parse ediliyor #######
			var1=$(echo $version_check4liberty | cut -f3 -d-)
				
			array4vers=(${var1//./ })
				
			var2="${array4vers[0]}.${array4vers[1]}.${array4vers[2]}.${array4vers[3]}"
			#####    Trimleme yapiliyor.     ######
			libertyVersion=${var2%%*( )}
			
			##### Java versiyon kontrolu yapiliyor ######			
			pathcheck4java=`ssh -q $HOST find /ibm/wlp/java/java/jre/bin/java` && java_existing_case=1 || echo -e "Sunucuda ibm altında java yoktur."
			
			if [ $java_existing_case -eq 1 ]
			then
				javaVersion=`ssh -q $HOST /ibm/wlp/java/java/jre/bin/java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
			fi
			
			##### Sunucu db2 baglantisi kontrol ediliyor ######
			pathcheck4db2driver=`ssh -q $HOST find /ibm/servers/*/lib/driver/db2/db2jcc4.jar | head -n 1` && db2driver_existing_case=1 || echo -e "db2 driver standart dizinde degildir."
			if [ $db2driver_existing_case -eq 0 ]
			then
				pathcheck4db2driver=`ssh -q $HOST find /ibm/servers -name 'db2jcc4.jar' | head -n 1`
			fi
			db2driverCheck=`ssh -q $HOST locate -q $pathcheck4db2driver` && echo -e "$HOST sunucusunda db2 driver bulunmaktadir. \n" && k=2 || echo -e "$HOST sunucusunda db2 driver bulunamamistir. \n"
			### buraya bir kontrol ###
			if [ $k -eq 2 ]
			then
				db2driverVersion=`ssh -q $HOST /ibm/wlp/java/java/jre/bin/java -cp $db2driverCheck com.ibm.db2.jcc.DB2Jcc -version 2>&1 | grep IBM | awk -F ' ' '{print $9}'`
			fi		
			
			##### Sunucu oracle baglantisi kontrol ediliyor ######
			pathcheck4ojdbc=`ssh -q $HOST find /ibm/servers/*/lib/driver/oracle/ojdbc*.jar` && ojdbc_existing_case=1 || echo -e "Sunucuda oracle connection olmayabilir veya driver standart path de degildir."
			if [ $ojdbc_existing_case -eq 0 ]
			then
				pathcheck4ojdbc=`ssh -q $HOST find /ibm/servers -name 'ojdbc*.jar' | grep -v workarea | grep -v tranlog | grep -v messaging`
				echo -e "$HOST sunucusunda ojdbc driver path i standart degildir. Sunucuda bu path duzeltilmelidir."
			fi
			ojdbcCheck=`ssh -q $HOST locate -q $pathcheck4ojdbc` && echo -e "$HOST sunucusunda OJDBC driver bulunmaktadir. \n" && k=3 || echo -e "$HOST sunucusunda OJDBC driver bulunamamistir. \n"
			
			#echo -e "$pathcheck4ojdbc"
			getJarName=0 ### if version func doesnt work get jar Name with getJarName=1
			if [ $k -eq 3 ]
			then
				fetchVersion=`ssh -q $HOST /ibm/wlp/java/java/jre/bin/java -jar $pathcheck4ojdbc -getversion 2>&1` || getJarName=1
				if [ $getJarName -eq 0 ]
				then
					ojdbcVersion=`ssh -q $HOST /ibm/wlp/java/java/jre/bin/java -jar $pathcheck4ojdbc -getversion 2>&1 | head -n 1 | awk -F 'on' '{print $1}'`
				else
					ojdbcVersion=`ssh -q $HOST basename $pathcheck4ojdbc`
				fi
			fi		
			
			##### TLS Versiyon Kontrolu ######
			tlsCheck=`ssh -q $HOST cat /ibm/servers/*/configDropins/overrides/*.xml | grep "TLSv1.2"` && tlsVersion="TLSv1.2" && echo -e "$HOST sunucusunda TLS versiyonu v1.2 dir."
			if [ "$tlsVersion" != "TLSv1.2" ]
			then

				tlsCheck2=`ssh -q $HOST cat /ibm/servers/*/server.xml | grep "TLSv1.2"` && echo -e "$HOST sunucusunda TLS versiyonu v1.2 dir. Tanım server.xml dedir." && tlsVersion="TLSv1.2" 
				
				if [ "$tlsVersion" != "TLSv1.2" ]
				then
					echo -e "$HOST sunucusunda TLS versiyonu v1.2 degildir." && tlsVersion="not TLSv1.2"
				fi
			fi
			
			
			echo -e "$HOST sunucusunda liberty versiyonu $libertyVersion dir. Sunucu bilgisi dosyaya yaziliyor. \n"
			echo -e "**************************************************************************************** \n\n\n"
			echo -e "liberty_server_versions,Host=$HOST;RHEL_Version=#$rhel_version#,liberty_version=#$libertyVersion#,java_version=#$javaVersion#,db2_version=#$db2driverVersion#,ojdbc_version=#$ojdbcVersion#,tls_version=#$tlsVersion#">>/usy/versioncheck/liberty_all_versions.txt
			
				
				
		else
				
			echo -e "Sunucu kontrol edilmelidir."
					
		fi
	else
	
		echo -e "$HOST sunucusu karalistedeki sunucular listesindedir."
	fi	
done
echo -e "Sunuculardan gerekli datalar toplanmistir. Datanın kafkaya gonderilmesi icin python scripti tetikleniyor."
trigger_senddata=`/opt/rh/rh-python36/root/usr/bin/python /usy/versioncheck/senddata2kafka_wlp.py >> /usy/versioncheck/logs/versioncheck_wlp.log`
#trigger_senddata=`python /usy/versioncheck/senddata2kafka_wlp.py >> /usy/versioncheck/logs/versioncheck_wlp.log`


