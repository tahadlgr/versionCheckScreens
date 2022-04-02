#!/bin/bash

cd /usy/versioncheck
. ./blacklist.bash
>/usy/versioncheck/was_all_versions.txt


HOSTS_lnx=$(python envanter_was_lnx.py)
HOSTS_aix=$(python envanter_was_aix.py)

FILE_PATH='/ibm/isbank_profiles'
arr2=( $HOSTS_lnx )
arr3=( $HOSTS_aix )
arr=( $variable )


for HOST in $HOSTS_lnx
do
	if [[ ! " ${arr[@]} " =~ " ${HOST} " ]]
	then
		echo -e "*******Islem yapilacak sunucu: $HOST*******"
		
		m=`grep -o . <<<"$HOST" | fold -w1 | tail -n 2 | head -n 1`  #### front of the last chracter
		n=`grep -o . <<<"$HOST" | fold -w1 | tail -n 1`   #### last chracter of hostname
		
		useOtherJava=0 #if java can not get version try other java
		
		file_info=0  ### isbank_profiles folder check variable
		
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
		
		##### MSsql verisi alinana kadar No_mssql verisi yazdirilir #######
		mssqlVersion="No_mssql_connection"
		mssql_existing_case=0 ## mssql check icin atanan degisken
		
		##### ims verisi alinana kadar No_ims verisi yazdirilir #######
		imsVersion="No_ims_connection"
		ims_existing_case=0 ## ims check icin atanan degisken
		
		##### installation manager versiyonu alinana kadar No_installation_manager infosu gecerlidir. ######
		installManVersion="No_installation_manager"
		ins_man_existing_case=0 ## im check icin atanan degisken
		
		##### Operating system verisi aliniyor #######
		rhel_version=`ssh -q $HOST cat /etc/redhat-release` && echo -e "Sunucunun isletim sistemi bilgisi alinmistir." && k=1 || echo -e "$HOST sunucusunda RHEL versiyonu alinamamistir. \n"
		
		ssh -q -o ConnectTimeout=30 $HOST [[ -e $FILE_PATH ]] && echo -e "$HOST sunucusunda $FILE_PATH dizini bulunmaktadir. \n" && file_info=1 || echo -e "$HOST sunucusunda $FILE_PATH dizini bulunamamistir. Ayrica ssh baglantisini kontrol edebilirsiniz. \n"
		if [ $file_info -eq 1 ]
		then
			info="file system is ok."
		else 
			info="no isbank_profiles folder"
		fi
		##### TLS Versiyon Kontrolu ######
		tlsVersion=`ssh $HOST cat /ibm/isbank_profiles/node$m$n/properties/ssl.client.props | grep com.ibm.ssl.protocol | head -n 1 | awk -F '=' '{print $2}'`
		if [[ $HOST == klbipwas* ]]   #### There is an exceptional case for klbipwas* hosts
		then
			tlsVersion=`ssh $HOST cat /ibm/isbank_profiles/node*/properties/ssl.client.props | grep com.ibm.ssl.protocol | head -n 1 | awk -F '=' '{print $2}'`
		fi
		
		if [ $k -eq 1 ]
		then
			wasVersion=`ssh -q $HOST /ibm/WebSphere/AppServer/bin/versionInfo.sh | grep -A1 'Network Deployment' | grep ^Version | awk '{print $2}'`
			
			##### Installation Manager kontrolleri yapiliyor. ######
			checking_install_manager=`ssh -q $HOST cat /ibm/InstallationManager/eclipse/configuration/config.ini` && ins_man_existing_case=1 || echo -e "installation manager bulunamamistir."
			if [ $ins_man_existing_case -eq 1 ]
			then
				installManVersion=`ssh -q $HOST cat /ibm/InstallationManager/eclipse/configuration/config.ini | grep -A0 'im.version' | awk -F '=' '{print $2}'`			
				echo -e "WAS installation manager versiyon bilgisi alinmistir."
			fi
			
			
			##### Sunucudaki java path leri ayıklanıyor ######			
			numberofjavapaths=`ssh -q $HOST find /ibm/WebSphere/AppServer/java*/ -name java | wc -l`
			numberofjavapaths="$(echo -e "$numberofjavapaths" | tr -d '[[:space:]]')"  ###trimming #Yarın buraya bak
			if [ $numberofjavapaths -gt 0 ]
			then
				for ((i=1; i<=$numberofjavapaths; i++))
				do
					###### Tum path lere sıra ile bakılarak java proseslerinde kullanılan java kontrol ediliyor. ######
					pathcheck4java=`ssh -q $HOST find /ibm/WebSphere/AppServer/java*/ -name java | head -n $i | tail -n 1` #Bir de buraya bak
					usedjavacheck=`ssh -q $HOST ps -ef | grep -c $pathcheck4java`
					
					if [ $usedjavacheck -gt 0 ]
					then 
						java_existing_case=1
						filetypeofpath=`ssh -q $HOST file $pathcheck4java | awk '{print $2}'`
						if [ "$filetypeofpath" != "directory"  ]
						then
							path4usedjava=$pathcheck4java
							echo -e "kullanilan java path: $path4usedjava"					
						else
							echo -e "kullanilan java path directory oldugu icin alternatifler kontrol ediliyor."
						fi
					fi
				done
			else
				echo -e "Sunucuda /ibm altında kullanılan java yoktur."
			fi
			##### Yukarıda cekilen kullanilan javanın versiyon kontrolu yapılıyor #######
			
			if [ $java_existing_case -eq 1 ]
			then
				javaVersion=`ssh -q $HOST $path4usedjava -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
			fi
			
						
			##### Sunucu db2 baglantisi kontrol ediliyor ######
			getpath4db2=`ssh -q $HOST cat /ibm/isbank_profiles/node$m$n/config/cells/*cell/variables.xml | grep DB2UNIVERSAL_JDBC_DRIVER_PATH | awk -F '"' '{print $6}'`
			
			pathcheck4db2driver=`ssh -q $HOST find $getpath4db2/db2jcc4.jar` && db2driver_existing_case=1 || echo -e "db2 driver bulunamamistir."
			
			if [ $db2driver_existing_case -eq 1 ]
			then
				db2driverVersion=`ssh -q $HOST $path4usedjava -cp $pathcheck4db2driver com.ibm.db2.jcc.DB2Jcc -version 2>&1 | grep IBM | awk -F ' ' '{print $9}'` && echo -e "db2 driver versiyonu alinmistir."
				if [[ "$javaVersion" == "No_java" ]]
				then
				db2driverVersion=`ssh -q $HOST java -cp $pathcheck4db2driver com.ibm.db2.jcc.DB2Jcc -version 2>&1 | grep IBM | awk -F ' ' '{print $9}'` && echo -e "db2 driver versiyonu alinmistir."
				fi
			fi
			
			
			##### Sunucu oracle baglantisi kontrol ediliyor ######
			getpath4ojdbc=`ssh -q $HOST cat /ibm/isbank_profiles/node$m$n/config/cells/*cell/variables.xml | grep ORACLE_JDBC_DRIVER_PATH | awk -F '"' '{print $6}'`
			
			pathcheck4ojdbcdriver=`ssh -q $HOST find $getpath4ojdbc/ojdbc*.jar` && ojdbc_existing_case=1 || echo -e "ojdbc driver bulunamamistir."
			
			if [ $ojdbc_existing_case -eq 1 ]
			then
				echo -e "ojdbc driver icin path ler taraniyor."
				pathcheck4ojdbcdriver=`ssh -q $HOST find $getpath4ojdbc/ojdbc*.jar | head -n 1`
				fetchVersion=`ssh -q $HOST $path4usedjava -jar $pathcheck4ojdbcdriver -getversion 2>&1` || useOtherJava=1
	
				if [ $useOtherJava -eq 0 ]
				then
					ojdbcVersion=`ssh -q $HOST $path4usedjava -jar $pathcheck4ojdbcdriver -getversion 2>&1 | head -n 1 | awk -F 'on' '{print $1}'` && echo -e "ojdbc driver versiyonu alinmistir."
					
				elif [[ $javaVersion == No_java ]]
				then
					ojdbcVersion=`ssh -q $HOST java -jar $pathcheck4ojdbcdriver -getversion 2>&1 | head -n 1 | awk -F 'on' '{print $1}'` && echo -e "ojdbc driver versiyonu alinmistir."
					
				elif [ $useOtherJava -eq 1 ]
				then
					fetchVersion=`ssh -q $HOST java -jar $pathcheck4ojdbcdriver -getversion 2>&1` || useOtherJava=2
		
					if [ $useOtherJava -eq 1 ]
					then
						ojdbcVersion=`ssh -q $HOST java -jar $pathcheck4ojdbcdriver -getversion 2>&1 | head -n 1 | awk -F 'on' '{print $1}'` && echo -e "ojdbc driver versiyonu alinmistir."
					else
						ojdbcVersion=`ssh -q $HOST basename $pathcheck4ojdbcdriver`
					fi
				fi
			fi
			
			##### IMS resource adapter kontrol ediliyor #######
			getpath4ims=`ssh -q $HOST find /ibm/isbank_profiles/node$m$n/ -name ims*.rar | head -n 1`
			checkpath4ims=`ssh -q $HOST find $getpath4ims/*/ra.xml` && ims_existing_case=1 || echo -e "$HOST sunucusunda ims connection yoktur."
			
			if [ $ims_existing_case -eq 1 ]
			then
				imsVersion=`ssh -q $HOST cat $checkpath4ims | grep resourceadapter-version | awk -F '>' '{print $2}' | awk -F '<' '{print $1}'`
				echo -e "ims version alinmistir."
			fi
			
			
			##### Sunucu MSsql baglantisi kontrol ediliyor ######
			getpath4mssql=`ssh -q $HOST cat /ibm/isbank_profiles/node$m$n/config/cells/*cell/variables.xml | grep MICROSOFT_JDBC_DRIVER_PATH | awk -F '"' '{print $6}'`

			pathcheck4mssqldriver=`ssh -q $HOST find $getpath4mssql/sqljdbc*.jar` && mssql_existing_case=1 || echo -e "Mssql jdbc driver bulunamamistir."
			
			if [ $mssql_existing_case -eq 1 ]
			then
				mssqlVersion="Succesful_conn"
				echo -e "mssql kontrolu eklenecek." #Buraya bir kod gelecek.
			fi
			
			
			
			echo -e "$HOST sunucusunda was versiyonu $wasVersion dir. Sunucu bilgisi dosyaya yaziliyor. \n"
			echo -e "**************************************************************************************** \n\n\n"
			echo -e "was_server_versions,Host=$HOST;RHEL_Version=#$rhel_version#,was_version=#$wasVersion#,java_version=#$javaVersion#,db2_version=#$db2driverVersion#,ojdbc_version=#$ojdbcVersion#,ims_adapt_version=#$imsVersion#,tls_version=#$tlsVersion#,server_info=#$info#,mssql_conn=#$mssqlVersion#,installation_manager_version=#$installManVersion#">>/usy/versioncheck/was_all_versions.txt
			
		else
				
			echo -e "Sunucu kontrol edilmelidir."	
		
		fi
		
	else
	
		echo -e "$HOST sunucusu karalistedeki sunucular listesindedir."
	fi	
done		


user="wasadm"


for HOST in $HOSTS_aix
do
	if [[ ! " ${arr[@]} " =~ " ${HOST} " ]]
	then
		m=`grep -o . <<<"$HOST" | fold -w1 | tail -n 2 | head -n 1`  #### front of the last chracter
		n=`grep -o . <<<"$HOST" | fold -w1 | tail -n 1`   #### last chracter of hostname
		echo -e "*******Islem yapilacak sunucu: $HOST*******"
		
		if [[ $HOST == kaofswas01 ]]
		then
			user="ofsa"
		elif [[ $HOST == kasaswas01 ]]
		then
			user="sas"
		else
			user="wasadm"
		fi
		
		useOtherJava=0 #if java can not get version try other java
		
		file_info=0  ### isbank_profiles folder check variable		
		
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
		
		##### MSsql verisi alinana kadar No_mssql verisi yazdirilir #######
		mssqlVersion="No_mssql_connection"
		mssql_existing_case=0 ## mssql check icin atanan degisken
		
		##### ims verisi alinana kadar No_ims verisi yazdirilir #######
		imsVersion="No_ims_connection"
		ims_existing_case=0 ## ims check icin atanan degisken
		
		##### installation manager versiyonu alinana kadar No_installation_manager infosu gecerlidir. ######
		installManVersion="No_installation_manager"
		ins_man_existing_case=0 ## im check icin atanan degisken
		
		##### Operating system verisi aliniyor #######
		aix_oslevel=`ssh -q $user@$HOST oslevel` && echo -e "Sunucunun isletim sistemi bilgisi alinmistir." && k=1 || echo -e "$HOST sunucusunda RHEL versiyonu alinamamistir. \n"
		
		ssh -q -o ConnectTimeout=30 $user@$HOST [[ -e $FILE_PATH ]] && echo -e "$HOST sunucusunda $FILE_PATH dizini bulunmaktadir. \n" && file_info=1 || echo -e "$HOST sunucusunda $FILE_PATH dizini bulunamamistir. Ayrica ssh baglantisini kontrol edebilirsiniz. \n"
		
		if [ $file_info -eq 1 ]
		then
			info="file system is ok."
		else 
			info="no isbank_profiles"
		fi
		
		##### TLS Versiyon Kontrolu ######
		tlsVersion=`ssh $user@$HOST cat /ibm/isbank_profiles/node$m$n/properties/ssl.client.props | grep com.ibm.ssl.protocol | head -n 1 | awk -F '=' '{print $2}'`
		
		
		if [ $k -eq 1 ]
		then
			wasVersion=`ssh -q $user@$HOST /ibm/WebSphere/AppServer/bin/versionInfo.sh | grep -A1 'Network Deployment' | grep ^Version | awk '{print $2}'`
			
			##### Installation Manager kontrolleri yapiliyor. ######
			checking_install_manager=`ssh -q $user@$HOST cat /ibm/InstallationManager/eclipse/configuration/config.ini` && ins_man_existing_case=1 || echo -e "installation manager bulunamamistir."
			if [ $ins_man_existing_case -eq 1 ]
			then
				installManVersion=`ssh -q $user@$HOST cat /ibm/InstallationManager/eclipse/configuration/config.ini | grep -A0 'im.version' | awk -F '=' '{print $2}'`			
				echo -e "WAS installation manager versiyon bilgisi alinmistir."
			fi
			
			##### Java versiyon kontrolu yapiliyor ######			
			##### Sunucudaki java path leri ayıklanıyor ######			
			numberofjavapaths=`ssh -q $user@$HOST find /ibm/WebSphere/AppServer/java*/ -name java | wc -l`
			numberofjavapaths="$(echo -e "$numberofjavapaths" | tr -d '[[:space:]]')"  ###trimming #Yarın buraya bak
			if [ $numberofjavapaths -gt 0 ]
			then
				for ((i=1; i<=$numberofjavapaths; i++))
				do
					###### Tum path lere sıra ile bakılarak java proseslerinde kullanılan java kontrol ediliyor. ######
					pathcheck4java=`ssh -q $user@$HOST find /ibm/WebSphere/AppServer/java*/ -name java | head -n $i | tail -n 1` #Bir de buraya bak
					usedjavacheck=`ssh -q $user@$HOST ps -ef | grep -c $pathcheck4java`
					
					if [ $usedjavacheck -gt 0 ]
					then 
						java_existing_case=1
						filetypeofpath=`ssh -q $user@$HOST file $pathcheck4java | awk '{print $2}'`
						if [ "$filetypeofpath" != "directory"  ]
						then
							path4usedjava=$pathcheck4java
							echo -e "kullanilan java path: $path4usedjava"					
						else
							echo -e "kullanilan java path directory oldugu icin alternatifler kontrol ediliyor."
						fi
					fi
				done
			else
				echo -e "Sunucuda /ibm altında kullanılan java yoktur."
			fi
			##### Yukarıda cekilen kullanilan javanın versiyon kontrolu yapılıyor #######
			
			if [ $java_existing_case -eq 1 ]
			then
				javaVersion=`ssh -q $user@$HOST $path4usedjava -version 2>&1 | head -n 1 | awk -F '"' '{print $2}'`
			fi
			
						
						
			##### Sunucu db2 baglantisi kontrol ediliyor ######
			getpath4db2=`ssh -q $user@$HOST cat /ibm/isbank_profiles/node$m$n/config/cells/*cell/variables.xml | grep DB2UNIVERSAL_JDBC_DRIVER_PATH | awk -F '"' '{print $6}'`
			
			pathcheck4db2driver=`ssh -q $user@$HOST find $getpath4db2/db2jcc4.jar` && db2driver_existing_case=1 || echo -e "db2 driver bulunamamistir."
			if [ $db2driver_existing_case -eq 1 ]
			then
				db2driverVersion=`ssh -q $user@$HOST $pathcheck4java -cp $pathcheck4db2driver com.ibm.db2.jcc.DB2Jcc -version 2>&1 | grep IBM | awk -F ' ' '{print $9}'` && echo -e "db2 driver versiyonu alinmistir."
			fi
			
			
			##### Sunucu oracle baglantisi kontrol ediliyor ######
			getpath4ojdbc=`ssh -q $user@$HOST cat /ibm/isbank_profiles/node$m$n/config/cells/*cell/variables.xml | grep ORACLE_JDBC_DRIVER_PATH | awk -F '"' '{print $6}'`
			
			pathcheck4ojdbcdriver=`ssh -q $user@$HOST find $getpath4ojdbc/ojdbc*.jar` && ojdbc_existing_case=1 || echo -e "ojdbc driver bulunamamistir."
			
			if [ $ojdbc_existing_case -eq 1 ]
			then
				echo -e "ojdbc driver icin path ler taraniyor."
				pathcheck4ojdbcdriver=`ssh -q $user@$HOST find $getpath4ojdbc/ojdbc*.jar | head -n 1`
				fetchVersion=`ssh -q $user@$HOST $path4usedjava -jar $pathcheck4ojdbcdriver -getversion 2>&1` || useOtherJava=1
	
				if [ $useOtherJava -eq 0 ]
				then
					ojdbcVersion=`ssh -q $user@$HOST $path4usedjava -jar $pathcheck4ojdbcdriver -getversion 2>&1 | head -n 1 | awk -F 'on' '{print $1}'` && echo -e "ojdbc driver versiyonu alinmistir."
					
				elif [[ $javaVersion == No_java ]]
				then
					ojdbcVersion=`ssh -q $user@$HOST java -jar $pathcheck4ojdbcdriver -getversion 2>&1 | head -n 1 | awk -F 'on' '{print $1}'` && echo -e "ojdbc driver versiyonu alinmistir."
					
				elif [ $useOtherJava -eq 1 ]
				then
					fetchVersion=`ssh -q $user@$HOST java -jar $pathcheck4ojdbcdriver -getversion 2>&1` || useOtherJava=2
		
					if [ $useOtherJava -eq 1 ]
					then
						ojdbcVersion=`ssh -q $user@$HOST java -jar $pathcheck4ojdbcdriver -getversion 2>&1 | head -n 1 | awk -F 'on' '{print $1}'` && echo -e "ojdbc driver versiyonu alinmistir."
					else
						ojdbcVersion=`ssh -q $user@$HOST basename $pathcheck4ojdbcdriver`
					fi
				fi
			fi
			
			##### IMS resource adapter kontrol ediliyor #######
			getpath4ims=`ssh -q $user@$HOST find /ibm/isbank_profiles/node$m$n/ -name ims*.rar | head -n 1`
			checkpath4ims=`ssh -q $user@$HOST find $getpath4ims/*/ra.xml` && ims_existing_case=1 || echo -e "$HOST sunucusunda ims connection yoktur."
			if [ $ims_existing_case -eq 1 ]
			then
				imsVersion=`ssh -q $user@$HOST cat $checkpath4ims | grep resourceadapter-version | awk -F '>' '{print $2}' | awk -F '<' '{print $1}'`
				echo -e "ims version alinmistir."
			fi
			
			if [ $mssql_existing_case -eq 1 ]
			then
				mssqlVersion="Succesful_conn"
				echo -e "mssql kontrolu eklenecek." #Buraya bir kod gelecek.
			fi
			
			
			echo -e "$HOST sunucusunda was versiyonu $wasVersion dir. Sunucu bilgisi dosyaya yaziliyor. \n"
			echo -e "**************************************************************************************** \n\n\n"
			echo -e "was_server_versions,Host=$HOST;aix_OsLevel=#$aix_oslevel#,was_version=#$wasVersion#,java_version=#$javaVersion#,db2_version=#$db2driverVersion#,ojdbc_version=#$ojdbcVersion#,ims_adapt_version=#$imsVersion#,tls_version=#$tlsVersion#,server_info=#$info#,mssql_conn=#$mssqlVersion#,installation_manager_version=#$installManVersion#">>/usy/versioncheck/was_all_versions.txt
			
		else
				
			echo -e "Sunucu kontrol edilmelidir."	
		
		fi
		
	else
	
		echo -e "$HOST sunucusu karalistedeki sunucular listesindedir."
	fi	
done	
			
trigger_senddata=`/opt/rh/rh-python36/root/usr/bin/python /usy/versioncheck/senddata2kafka_was.py >> /usy/versioncheck/logs/versioncheck_was.log`				