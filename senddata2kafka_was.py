
from kafka import KafkaProducer
from datetime import datetime
import time



def main():
    send_data()


def send_data():
    try:
        current_timestamp = str(int(datetime.now().timestamp() * 1000000000))
        current_timestamp = current_timestamp.strip()
        producer = KafkaProducer(bootstrap_servers=['kafkahost1', 'kafkahost2', 'kafkahost3']) 
        
        
        with open('/usy/versioncheck/was_all_versions.txt') as f:
            readed_line=str()
            lines = f.readlines()
            for line in lines:
            
                readed_line = str(line)
                readed_line = readed_line.strip()
                readed_line = readed_line.replace(" ","_")
                readed_line = readed_line.replace(";"," ")
                readed_line = readed_line.replace("#","\"")
                data=readed_line + " " + current_timestamp
                print(data)
                time.sleep(0.2)
                producer.send('custommon', bytes(data, 'utf-8'))
                producer.flush()
                                
            #    f.close()

            
        print("---")
        print("WAS sunuculari versiyonlari icin data gonderimi tamamlanmistir. ")
    except:
        print("An exception occurred")


if __name__ == "__main__":
    main()