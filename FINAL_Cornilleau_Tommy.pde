import SimpleOpenNI.*;                                                                                                                  //Importe Openni
import ddf.minim.*;                                                                                                                     //Importe minim (pour la gestion du son)

Minim minim;                                                                                                                            //déclaration de minim/variable globale
AudioPlayer player;                                                                                                                     //déclaration du player/variable globale

SimpleOpenNI context;                                                                                                                   //déclaration Simple Openni /variable globale
float        zoomF =0.5f;
float        rotX = radians(180);                                                                                                       // by default rotate the hole scene 180deg around the x-axis, 
// the data from openni comes upside down
float        rotY = radians(0);

int          maxUser = 4;                                                                                                               //Nombre d'utilisateur max
PVector[]    oldPos  = new PVector[15*maxUser];                                                                                         //Tableau qui contient les coordonnées des articulations du squelettes à la frame précédente/variable globale. 15*4 va lui permettre de stocker les coordonnées de 4 utilisateurs différents
int          compteur = 0;                                                                                                              //Compteur qui va s'incrémenter pour permettre de mettre en place un délai pour prendre en compte le déplacement/variable globale
int          chgt = 0;                                                                                                                  //Variable qui va s'incrémenter pour prendre en compte le nombre de changement de position des articulations du squelette d'une frame à l'autre/variable globale
int          distMin=2000;

void setup()
{
  size(1024, 768, P3D);                                                                                                                 //Définition de la taille de la scene
  context = new SimpleOpenNI(this);                                                                                                     //Définition de la variable simpleOpenni
  if (context.isInit() == false)                                                                                                        //Teste la connexion de la kinect
  {
    println("Can't init SimpleOpenNI, maybe the camera is not connected!"); 
    exit();                                                                                                                             //Quitte le programme si la Kinect n'est pas branchée
    return;
  }

  context.setMirror(false);                                                                                                             //Désactive le setMirror

  context.enableDepth();                                                                                                                //Active la captation de la profondeur 

  context.enableUser();                                                                                                                 //Active la détection de squelette

  smooth();  
  perspective(radians(45), 
  float(width)/float(height), 
  10, 150000);                                                                                                                           //Place la scene en perspective

  minim = new Minim(this);                                                                                                               //Définition de la variable minim
  player = minim.loadFile("dn3s_-_Frag_Mango.mp3", width);                                                                               //Charge le fichier audio avec bufergin égale à la scene pour pouvoir le dessiner sur toute sa largeur


  for (int i = 0; i < oldPos.length; i=i+1 ) {                                                                                           //Boucle permettant de déclarer les objets PVector dans le tableau oldPos
    oldPos[i] = new PVector();
  }
}

void draw()
{
  context.update();                                                                                                                      //Update de la kinect

  background(0, 0, 0);                                                                                                                   //Place un background noir

  translate(width/2, height/2, 0);                                                                                                       //Place la scene en largeur/profondeur, de manière à pouvoir jouer avec la rotation, par exemple
  rotateX(rotX);
  rotateY(rotY);
  scale(zoomF);

  int[]   depthMap = context.depthMap();                                                                                                  
  int[]   userMap = context.userMap();
  int     steps   = 3;                                                                                                                    //Pas des poins tracés (trace 1 point sur 3)
  int     index;                                                                                                                          //Coordonnée des points tracés
  PVector realWorldPoint;                                                                                                                 //Points à tracer de la kinect;

  translate(0, 0, -1000);                                                                                                                 //Place le point de rotation à 1000


  beginShape(POINTS);                                                                                                                     //Début tracage des points de la kinect                                          
  for (int y=0;y < context.depthHeight();y+=steps)                                                                                        //parcours selon l'axe y
  {
    for (int x=0;x < context.depthWidth();x+=steps)                                                                                       //parcours selon l'axe x
    {
      index = x + y * context.depthWidth();                                                                                               //Coordonnée du tableau du point actuellement tracé
      if (depthMap[index] > distMin)                                                                                                         //N'affiche que les points si supérieurs à distMin pour avoir un affichage du squelette correct
      { 
        realWorldPoint = context.depthMapRealWorld()[index];                                                                              //Affecte le point actuellement tracé à la variable
        if (userMap[index] == 0)                                                                                                          //Test l'appartenance des ponts (humain ou pas)
        { 
          stroke(0);                                                                                                                      //Si les points n'appartiennent pas à un humain, alors ils ne s'affichent pas
        } 
        else
          stroke(100);                                                                                                                    //Les points humains sont tracés en gris

        point(realWorldPoint.x, realWorldPoint.y + (player.left.get(x)*(realWorldPoint.y)), realWorldPoint.z);                          //Les coordonnées y des points varient lors de leur affichage en fonction de la musique jouée
      }
    }
  } 
  endShape();


  int[] userList = context.getUsers();                                                                                                     //Met les idUser dnas le tableau userList   
  if (userList.length>maxUser)                                                                                                             //Limite l'application à 4 personnes pour ne pas avoir un résulltat trop fouillit
  {
    for (int i=0;i<maxUser;i++)                                                                                                            //Appel la fonction detectMouvement pour le maximum d'utilisateurs
    {
      detectMouvement(userList[i]);
    }
  }
  else
  {
    for (int i=0;i<userList.length;i++)                                                                                                     //Appel la fonction detectMouvement pour tout les utilisateurs actuels
    {
      detectMouvement(userList[i]);
    }
  }

  if (compteur/(frameRate)>=0.5)                                                                                                            //Effectue les actions toutes les 0.5 secondes
  {
    compteur = 0;                                                                                                                           //Réinitialise le compteur quand il effectue les actions
    println(chgt);
    if (chgt >= 1)
      player.pause();                                                                                                                       //Si l'utilisateur bouge, la musique se met en pause
    else
    {
      player.play();                                                                                                                        //A l'inverse, il se met en lecture
      if (player.position() >= player.length()-1000)                                                                                        //A 1 seconde de la fin de la musique il la remet au début                                                                                    
        player.rewind();
    }

    chgt = 0;                                                                                                                               //Réinitialise la variable chgt
  }
  compteur++;                                                                                                                               //incrémente le compteur à chaque frame
}

void detectMouvement(int userId)
{
  PVector[]    nowPos  = new PVector[15];                                                                                                   //Déclare le tableau nowPos, qui va contenir les positions des articulations du squelette
  for (int i = 0; i < nowPos.length; i=i+1 ) {
    nowPos[i] = new PVector();                                                                                                              //Déclare un objet PVector à chaque indice du tableau
  }
  //PVector nowPos = new PVector();
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_HEAD, nowPos[0]);                                                              //Récupère les positions de chaque articulation du squelette pour les placer à chaque rang du tableau nowPos
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_NECK, nowPos[1]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_LEFT_SHOULDER, nowPos[2]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_LEFT_ELBOW, nowPos[3]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_LEFT_HAND, nowPos[4]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_RIGHT_SHOULDER, nowPos[5]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_RIGHT_ELBOW, nowPos[6]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_RIGHT_HAND, nowPos[7]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_TORSO, nowPos[8]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_LEFT_HIP, nowPos[9]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_LEFT_KNEE, nowPos[10]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_LEFT_FOOT, nowPos[11]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_RIGHT_HIP, nowPos[12]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_RIGHT_KNEE, nowPos[13]);
  context.getJointPositionSkeleton(userId, SimpleOpenNI.SKEL_RIGHT_FOOT, nowPos[14]);

  for (int i = 0; i < nowPos.length; i=i+1 )                                                                                                //Parcours le tableau nowPos
  {
    if (((nowPos[i].x > oldPos[i+((userId-1)*15)].x+50 || nowPos[i].x < oldPos[i+((userId-1)*15)].x-50) || (nowPos[i].y > oldPos[i+((userId-1)*15)].y+50 || nowPos[i].y < oldPos[i+((userId-1)*15)].y-50) || (nowPos[i].z > oldPos[i+((userId-1)*15)].z+50 || nowPos[i].z < oldPos[i+((userId-1)*15)].z-50)) && (nowPos[i].z > distMin))
    {                                                                                                                                       //Compare les positions actuels aux anciennes/"i+((userId-1)*15)" permet d'avoir les anciennes positions d'un user précis, et identifié
      chgt++;                                                                                                                               //Si une des articlation a bougé de plus de 50, on incrémente la variable chgt
    }
    oldPos[i+((userId-1)*15)] = nowPos[i];                                                                                                  //La valeur des articulations de l'utilisateur dans nowPos sont affectées à oldPos
  }
}


// -----------------------------------------------------------------
// SimpleOpenNI user events

void onNewUser(SimpleOpenNI curContext, int userId)
{
  println("onNewUser - userId: " + userId);
  println("\tstart tracking skeleton");

  context.startTrackingSkeleton(userId);                                                                                                     //Permet de tracker les squelettes
}

void onLostUser(SimpleOpenNI curContext, int userId)
{
  println("onLostUser - userId: " + userId);
}

void onVisibleUser(SimpleOpenNI curContext, int userId)
{
  //println("onVisibleUser - userId: " + userId);
}


// -----------------------------------------------------------------
// Keyboard events

void keyPressed()
{
  switch(key)
  {
  case ' ':
    context.setMirror(!context.mirror());
    break;
  }

  switch(keyCode)
  {
  case LEFT:                                                                                                                                    //Rotation à gauche
    rotY += 0.1f;
    break;
  case RIGHT:                                                                                                                                   //Rotation à droit
    // zoom out
    rotY -= 0.1f;
    break;
  case UP:
    if (keyEvent.isShiftDown())                                                                                                                 //Zoomer
      zoomF += 0.01f;
    else
      rotX += 0.1f;                                                                                                                             //Rotation vers le haut
    break;
  case DOWN:
    if (keyEvent.isShiftDown())                                                                                                                 //Dézoomer
    {
      zoomF -= 0.01f;
      if (zoomF < 0.01)
        zoomF = 0.01;                                                                                                                           //Maximum de dézoom
    }
    else
      rotX -= 0.1f;                                                                                                                             //Rotation vers le bas
    break;
  }
}

void stop()                                                                                                                                      //Ferme toutes les pistes audio
{
  player.close();
  minim.stop();
  super.stop();
}

