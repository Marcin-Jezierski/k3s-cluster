## 1. Ingress zwracał bład 404.
Na początku miałem problem z Ingressem.
Mimo że Ingress powinien kierować ruch do serwisu frontend-nginx, stale dostawałem błąd 404.
Dawało to informację, że Ingress działa, ale przekierowanie jest źle skonfigurowane.

Po dłuższym debugowaniu okazało się, że problem wynikał z konfliktu portu 80 na hoście.
Podczas tworzenia klastra mapowałem port loadbalancera jako 80:80@loadbalancer i próbowałem wyświetlić stronę na domyślnym porcie 80.
Jednak na Windowsie port 80 był już zajęty przez proces host-switch.exe należący do Rancher Desktop, który zarządza siecią klastra.
W efekcie ruch na localhost:80 nie trafiał do mojego Ingressa, tylko do tego procesu, co powodowało błąd 404 i mylne wrażenie błędnej konfiguracji mojego ingressu.

Rozwiązaniem było użycie innego portu hosta, np. 8086:80@loadbalancer, aby uniknąć konfliktu i poprawnie kierować ruch do mojego serwisu.

## 2. Problem z lokalizacją plików HTML w podzie frontend-nginx

Kolejnym problemem było poprawne umiejscowienie plików HTML w kontenerze nginx, który pochodzi z oficjalnego Helm Charta Bitnami.
Domyślnie spodziewałem się, że serwer NGINX będzie szukał plików w katalogu /usr/share/nginx/html, zgodnie z klasyczną konfiguracją.

Okazało się jednak, że chart Bitnami zmienia domyślną lokalizację katalogu root w konfiguracji serwera na /app.
Dopiero po zamontowaniu ConfigMapa z HTML-em do ścieżki /app, pliki zaczęły się poprawnie wyświetlać.
Montaż do /usr/share/nginx/html nie działał.

## 3. Problem z wyświetlaniem zdjęć i dostępem do Minio
Zdjęcia poprawnie wyświetlały się tylko wtedy, gdy port Minio był bezpośrednio forwardowany na maszynę lokalną. W przeciwnym wypadku zdjęcia się nie ładowały.
Aby to naprawić, próbowałem w Ingressie frontend-nginx ustawić przekierowanie do serwisu Minio, tak aby mieć dostęp do zdjęć spoza klastra. Chciałem to zrobić za pomocą konfiguracji serverBlock, jednak z braku czasu musiałem zrezygnować z tego rozwiązania.

Ostatecznie zdecydowałem się na utworzenie osobnego Ingressu dla Minio i od tego momentu dostęp do zdjęć działał poprawnie.
