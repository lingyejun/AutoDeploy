#! /bin/bash

## Deploy automatically'shell script
## Writen by chao03.li 2017-08-08

#-----------------------------------------------------入参赋值-------------------------------------------------------
echo hostname=$HOSTNAME

jar_wrapper_ops=${1}

pom_groupid=${2}
pom_artifactid=${3}
pom_version=${4}
pom_displayname=${5}

job_name=$6
build_number=$7
build_id=$8
build_url=$9
git_url=${10}
git_branch=${11}
git_commit=${12}
artifact_url=${13}
extra_options=${14}

#--------------------------完整参数--------------------------
echo "$1 $2 $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 $artifact_url $14"

serviceName=${pom_groupid}-${pom_artifactid}

echo job_name=$job_name
echo build_number=$build_number
echo build_id=$build_id
echo build_url=$build_url
echo git_url=$git_url
echo git_branch=$git_branch
echo git_commit=$git_commit
echo artifact_url=$artifact_url
echo pom_displayname=$pom_displayname
echo pom_version=$pom_version
echo pom_groupid=$pom_groupid
echo pom_artifactid=$pom_artifactid
echo jar_wrapper_ops=$jar_wrapper_ops
echo extra_options=$extra_options
echo serviceName=$serviceName

DEPLOY_BASE_DIR="/root/deploy"
#----------------------------------------检查必须要素---------------------------------------------
if [ -z $jar_wrapper_ops ]; then
  echo "jar_wrapper_ops is unset";
  exit 1
fi

if [ -z $pom_groupid ]; then
  echo "pom_groupid is unset";
  exit 1
fi

if [ -z $pom_artifactid ]; then
  echo "pom_artifactid is unset";
  exit 1
fi
#-------------------------------------目录变量赋值-----------------------------------------------
# 主目录
# RDECK_BASE must be set and exisot
# -d ：判断制定的是否为目录,存在且是一个目录则为真.
# -z ：判断制定的变量是否存在值,“STRING” 的长度为零则为真.
# -a : 逻辑与如果exp1和exp2都为真，则exp1 -a exp2返回真.
# -o : 逻辑或只要exp1和exp2任何一个为真，则exp1 -o exp2 返回真.
# shell多命令执行';'和'&&'命令
# 用';' ---------是先执行第一个命令，不管第一个命令是否出错都执行下一个命令。
# 用'&&'--------是当第一个命令正确执行完毕后，才执行下一个命令，类似短路。

[ -z "$DEPLOY_BASE_DIR" -o ! -d "$DEPLOY_BASE_DIR" ] && {
    echo "DEPLOY_BASE_DIR not set or does not exist" ;
    exit 1 ;
}

# 二级目录：upload和instance
UPLOAD_DIR="$DEPLOY_BASE_DIR/upload"
INSTANCE_DIR="$DEPLOY_BASE_DIR/instance"
echo DEPLOY_BASE_DIR=$DEPLOY_BASE_DIR
echo UPLOAD_DIR=$UPLOAD_DIR

#此次上传的JAR包的具体路径
jarFullPath=${UPLOAD_DIR}/${artifact_url}
echo jarFullPath=$jarFullPath

#此次上传的TAR包的具体路径
tarFullPath=${UPLOAD_DIR}/${artifact_url}
echo tarFullPath=$tarFullPath

#baseDir/instance/serviceName的一级目录
serviceBasePath=${INSTANCE_DIR}/${pom_groupid}/${pom_artifactid}
echo serviceBasePath=$serviceBasePath
# 创建serviceName下的子目录
LOGS_DIR=logs
JAR_DIR=${serviceBasePath}/jar
TAR_DIR=${serviceBasePath}/tar
LOG_DIR=${serviceBasePath}/${LOGS_DIR}
echo JAR_DIR=$JAR_DIR
echo LOG_DIR=$LOG_DIR

# 所有操作都要使用到pid, lock文件
PID_FILE=$serviceBasePath/pid
LOK_FILE=$serviceBasePath/lock
HEAD=${serviceBasePath}/HEAD
echo "PID_FILE: $PID_FILE"
echo "LOK_FILE: $LOK_FILE"
echo "HEAD: $HEAD"


# target下的路径
target_webapps_dir=$MQTT_BASE_DIR/target
target_bin_dir=$MQTT_BASE_DIR/target/bin

# 其它
RETVAL=0
DATE=`/bin/date +%Y%m%d-%H%M%S`
echo DATE=$DATE
#--------------------------------------返回结果函数---------------------------------
# 打印成功时的返回结果
echo_success() {
    echo "[OK]"
    return 0
}
# 打印失败时的返回结果
echo_failure() {
    echo "[FAILED]"
    return 1
}
#-----------------------------------判断文件是否可写------------------------------
# 检查目录是否可写 0-校验成功，目录可写。 1-目录不可写。
# -w:判断制定的是否可写,如果 FILE 如果 FILE 存在且是可写的则为真。
# 命令之间使用 || 连接，实现逻辑或的功能,只要有一个命令返回真（命令返回值 $? == 0），后面的命令就不会被执行。

checkDirWritable() {
    echo "checkDirWritable"

    # 检查主目录是否可写
    [ -w $DEPLOY_BASE_DIR ] || {
        echo "DEPLOY_BASE_DIR dir not writable: $DEPLOY_BASE_DIR"
        return 1;
    }
    # 检查UPLOAD_DIR目录是否可写
    [ -w $UPLOAD_DIR ] || {
        echo "UPLOAD_DIR dir not writable: $UPLOAD_DIR"
        return 1;
    }
    # 检查INSTANCE_DIR目录是否可写
    [ -w $INSTANCE_DIR ] || {
        echo "INSTANCE_DIR dir not writable: $INSTANCE_DIR"
        return 1;
    }
    # 检查serviceBasePath目录是否可写
    [ -w $serviceBasePath ] || {
        echo "serviceBasePath dir not writable: $serviceBasePath"
        return 1;
    }
    # 检查JAR_DIR目录是否可写
    [ -w $JAR_DIR ] || {
        echo "JAR_DIR dir not writable: $JAR_DIR"
        return 1;
    }
    # 检查LOG_DIR目录是否可写
    [ -w $LOG_DIR ] || {
        echo "LOG_DIR dir not writable: $LOG_DIR"
        return 1;
    }

    return 0
}
#------------------------------------------创建文件夹---------------------------------
#创建文件夹并检查是否创建成功
init() {
    echo "initing $serviceName"

    # 创建文件夹
    echo "Creating dir..."
    mkdir -p $UPLOAD_DIR
    mkdir -p $INSTANCE_DIR

    mkdir -p $JAR_DIR
    mkdir -p $TAR_DIR
    mkdir -p $LOG_DIR
    mkdir -p ${serviceBasePath}/target

    #检查文件夹是否创建成功
    echo "Testing dir..."
    checkDirWritable

    return $?
}

# -eq          //等于
# -ne          //不等于
# -gt          //大于
# -lt          //小于
# -ge          //大于等于
# -le          //小于等于
start() {
    echo "Starting Mqtt..."

    # 检查是否存在
    echo "Testing dir..."
    checkDirWritable
    if [[ $? -ne 0 ]]; then
      echo_failure;
      return 1
    fi

    printf "%s" "Begin starting $serviceName: "

    #TODO
    # [ -f $LOK_FILE -a -f $PID_FILE ] && {
    #   echo "already running $serviceName"
    # 	echo_success; #already running
    # 	return 0
    # }
    #
    # [ ! -f $HEAD ] && {
    #   echo "HEAD is null: $HEAD"
    #   return 1
    # }


    #TODO sharedwifi要添加 log 等参数
    GC_LOG_FILE=${LOGS_DIR}/gc_$DATE.log
    LOG_FILE=$LOG_DIR/$DATE.log
    echo "GC_LOG_FILE: $GC_LOG_FILE"
    echo "LOG_FILE: $LOG_FILE"

    # ${JAVA_HOME}/bin/


    # 进入到target的bin目录下然后执行启动脚本
    pwd
    cd ${serviceBasePath}/target
    pwd
    rm -rf ${serviceBasePath}/target/*
    tar zxf ${serviceBasePath}/HEAD -C ${serviceBasePath}/target


    #为了能够后台运行，我们需要使用nohup这个命令，比如我们有个start.sh需要在后台运行，并且希望在后台能够一直运行，那么就使用nohup
    #比如cat > test.c，这个表示向test.c文件重新添加内容，test.c文件首先被清空。
    #而cat >> test.c，这个表示想test.c文件追加内容，test.c中原来的内容不会被清理掉。
    #shell上0表示标准输入
    #       1表示标准输出
    #       2表示标准错误输出
    #  2>&1:把标准错误输出重定向到标准输出
    #  & >file：把标准输出和标准错误输出都重定向到文件file中
    #nohup $rundeckd >>$LOG_FILE 2>&1 &
    #执行target启动脚本
    #source bin/moquette.sh 
    #rundeckd="java ${RDECK_JVM} -server -XX:+UseG1GC -XX:G1RSetUpdatingPauseTimePercent=5 -XX:MaxGCPauseMillis=500 -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintHeapAtGC -XX:+PrintTenuringDistribution -XX:+PrintGCApplicationStoppedTime -XX:+PrintPromotionFailure -Xloggc:/var/log/moquette/gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=10M -XX:+HeapDumpOnOutOfMemoryError -Djava.awt.headless=true -Dlog4j.configuration=file:/root/software/moquette/distribution-0.11-SNAPSHOT-bundle-tar/config/moquette-log.properties -Dmoquette.path=/root/software/moquette/distribution-0.11-SNAPSHOT-bundle-tar/ -cp /root/software/moquette/distribution-0.11-SNAPSHOT-bundle-tar/lib/* io.moquette.server.Server"
    source /etc/profile
    cd *
    #nohup sh ./bin/*.sh >>$LOG_FILE 2>&1 &
    cd bin
    chmod a+x ./*
    nohup sh start.sh >>$LOG_FILE 2>&1 &
    RETVAL=$?
    PID=$!
    #pPID=$!
    #echo "pPID = $pPID"
    #sleep 10
    #PID=`pstree -p $pPID | head -n 1 | awk -F')'  '{print $2}' | awk -F'('  '{print $2}'`
    echo $PID > $PID_FILE
    echo "PID = $PID"
    if [ $RETVAL -eq 0 ]; then
    	touch $LOK_FILE
    	echo_success
    else
	     echo_failure
    fi

    return $RETVAL
}

#
stop() {
    echo "Stopping $serviceName"

    echo "Testing dir..."
    checkDirWritable
    if [[ $? -ne 0 ]]; then
      echo_failure;
      return 1
    fi

    [ ! -f $PID_FILE ] && {
      echo "Stop: not exist pid file, return directly"
    	return 0
    }

    PID=`cat $PID_FILE`
    RETVAL=$?
    [ -z "$PID" ] && {
      echo "Stop fail: empty pid file"
    	echo_failure; #empty pid value"
    	return 1;
    }
    pPID=$(ps -ef | grep $PID | grep -v grep |awk '{print $2}'| egrep -v "^1$|$PID")
    echo "Searching process with pid: $PID"
    ps -p "$PID" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "PID($PID) exist, stopping process..."
        #kill $PID >/dev/null 2>&1   生产环境命令
    	kill -9 $PID >/dev/null 2>&1  #测试、开发环境
    	RETVAL=$?
    	[ $RETVAL -eq 0 ] || {
          echo "Stop fail: could not kill process"
    	    echo_failure; # could not kill process
    	    return 2
    	}
      echo "Stop exiting process success"
    else
      echo "Cannot find process with pid: $PID"
    fi
    
    rm -f $PID_FILE; # Remove control files
    rm -f $LOK_FILE
    # 如果是父进程启动的：
    echo "父进程ID:$pPID"
    # 不是挂在 init 上：
    if [[ $pPID -ne 1 ]]; then
      kill $pPID ;
      echo "kill pPID: $pPID ";
    fi
    echo_success
    return 0
}

#
deploy() {
  echo "Deploying $serviceName"

  #检查文件夹是否创建成功
  echo "Testing dir..."
  checkDirWritable
  echo $?
  if [[ $? -ne 0 ]]; then
    echo "dir illeage"
    return 1;
  fi

  [ ! -f $tarFullPath ] && {
      echo "tarFullPath not exist: $tarFullPath" ;
      return 1;
  }

  # 移动到 serviceName 中的 tar文件夹
  dstTarFullPath=$TAR_DIR/${artifact_url}
  echo dstTarFullPath=$dstTarFullPath
  rm -rf $dstTarFullPath
  mv $tarFullPath $dstTarFullPath

  # 将软引用指向新的 jar 包
  ls -l $serviceBasePath
  rm -f $HEAD
  ln -s $dstTarFullPath $HEAD
  ls -l $serviceBasePath

  # 停止原来的服务
  stop
  echo "==========================================是否正常停止 $?"
  if [[ $? -ne 0 ]]; then
    echo "fail to stop"
  fi

  #休眠10s等待tomcat关闭
  sleep 10;
  
  # 启用新的服务
  start
  if [[ $? -ne 0 ]]; then
    echo "fail to start: $serviceName"
    return 1;
  fi

  # 检查下
  status
  if [[ $? -ne 0 ]]; then
      echo "fail to start: $serviceName ";
      return 1;
  fi

  return 0;
}

#
status() {
    echo "Statusing $serviceName"

    echo "Testing dir..."
    checkDirWritable
    if [[ $? -ne 0 ]]; then
      echo_failure;
      return 1
    fi

    RETVAL=0
    test -f "$PID_FILE"
    RETVAL=$?
    [ $RETVAL -eq 0 ] || {
        echo "$serviceName is stopped";
	      return 1;
    }

    PID=`cat $PID_FILE`
    ps -p "$PID" >/dev/null
    RETVAL=$?
    [ $RETVAL -eq 0 ] && {
	     echo "Is running (pid=$PID, port=$RDECK_PORT): $serviceName ";
       return 0;
    } || {
	     echo "dead but pid file exists: $serviceName "
       return 2;
    }

    return 0;
}

# case语句适用于需要进行多重分支的应用情况。
# case分支语句的格式如下：
#  case $变量名 in
#  模式1）
#  命令序列1
#  ;;
#  模式2）
#  命令序列2
#  ;; 
#  *）
#  默认执行的命令序列     ;; 
#   esac

#  $? 上个命令的退出状态，或函数的返回值。

case "$jar_wrapper_ops" in
    init)
  init
  RETVAL=$?
  ;;
    deploy)
  deploy
  RETVAL=$?
  ;;
    start)
	start
  RETVAL=$?
	;;
    stop)
	stop
  RETVAL=$?
	;;
    restart)
	stop
	start
  RETVAL=$?
	;;
    condrestart)
	if [ -f $LOK_FILE ]; then
	    stop
	    start
	fi
	;;
    status)
	#status $rundeckd #临时去除
  status
	RETVAL=$?
	;;
    *)
	echo $"Usage: $0 {init|deploy|start|stop|restart|condrestart|status}"
	RETVAL=1
esac

# exit命令用于退出当前shell，在shell脚本中可以终止当前脚本执行。
exit $RETVAL 
