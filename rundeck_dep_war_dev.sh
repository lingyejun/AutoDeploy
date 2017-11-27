#! /bin/bash -ilex

## Deploy automatically'shell script
## Writen by chao03.li 2017-08-09

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

[ -z "$TOMCAT_BASE_DIR" -o ! -d "$TOMCAT_BASE_DIR" ] && {
    echo "TOMCAT_BASE_DIR not set or does not exist" ;
    exit 1 ;
}

# 二级目录：upload和instance
UPLOAD_DIR="$DEPLOY_BASE_DIR/upload"
INSTANCE_DIR="$DEPLOY_BASE_DIR/instance"
echo DEPLOY_BASE_DIR=$DEPLOY_BASE_DIR
echo UPLOAD_DIR=$UPLOAD_DIR

#此次上传的WAR包的具体路径
jarFullPath=${UPLOAD_DIR}/${artifact_url}
echo jarFullPath=$jarFullPath

#baseDir/instance/serviceName的一级目录
serviceBasePath=${INSTANCE_DIR}/${pom_groupid}/${pom_artifactid}
echo serviceBasePath=$serviceBasePath
# 创建serviceName下的子目录
LOGS_DIR=logs
WAR_DIR=${serviceBasePath}/war
LOG_DIR=${serviceBasePath}/${LOGS_DIR}
echo WAR_DIR=$WAR_DIR
echo LOG_DIR=$LOG_DIR

# 所有操作都要使用到pid, lock文件
#PID_FILE=$serviceBasePath/pid
#LOK_FILE=$serviceBasePath/lock
HEAD=${serviceBasePath}/HEAD
#echo "PID_FILE: $PID_FILE"
#echo "LOK_FILE: $LOK_FILE"
echo "HEAD: $HEAD"

#tomcat下的路径
tomcat_webapps_dir=$TOMCAT_BASE_DIR/webapps
tomcat_bin_dir=$TOMCAT_BASE_DIR/bin

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
    #检查tomcat目录是否可写
    [ -w $TOMCAT_BASE_DIR ] || {
        echo "TOMCAT_BASE_DIR dir not writable: $TOMCAT_BASE_DIR"
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
    # 检查WAR_DIR目录是否可写
    [ -w $WAR_DIR ] || {
        echo "WAR_DIR dir not writable: $WAR_DIR"
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

    mkdir -p $WAR_DIR
    mkdir -p $LOG_DIR
    mkdir -p ${serviceBasePath}/tomcat_map
 
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
    echo "Starting Tomcat..."

    # 检查是否存在
    echo "Testing dir..."
    checkDirWritable
    if [[ $? -ne 0 ]]; then
      echo_failure;
      return 1
    fi

    printf "%s" "Begin starting $serviceName: "
    
    # 进入到tomcat的bin目录下然后执行启动脚本
    pwd
    cd $tomcat_bin_dir 
    pwd
    #执行tomcat启动脚本
    ./startup.sh
 
    return $RETVAL
}

#停止tomcat
stop() {
    echo "Stopping Tomcat..."

    echo "Testing dir..."
    checkDirWritable
    if [[ $? -ne 0 ]]; then
      echo_failure;
      return 1
    fi
    
    # 进入到tomcat的bin目录下然后执行启动脚本
    pwd
    cd $tomcat_bin_dir
    pwd
    #执行tomcat的停止脚本
    ./shutdown.sh

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

  [ ! -f $jarFullPath ] && {
      echo "jarFullPath not exist: $jarFullPath" ;
      return 1;
  }

  # 移动到 serviceName 中的 war文件夹
  # UPLOAD_DIR="$DEPLOY_BASE_DIR/upload"
  # jarFullPath=${UPLOAD_DIR}/${artifact_url}
  # serviceBasePath=${INSTANCE_DIR}/${pom_groupid}/${pom_artifactid}
  # WAR_DIR=${serviceBasePath}/war
  dstJarFullPath=$WAR_DIR/${artifact_url}
  #打印涉及到的路径信息
  echo 打印涉及到的路径信息:
  echo WAR_DIR=$WAR_DIR
  echo UPLOAD_DIR=$UPLOAD_DIR
  echo dstJarFullPath=$dstJarFullPath
  echo jarFullPath=$jarFullPath
  echo serviceBasePath=$serviceBasePath 

  rm -rf $dstJarFullPath
  echo dstJarFullPath=$dstJarFullPath
  echo jarFullPath=$jarFullPath
  mv $jarFullPath $dstJarFullPath
 
  # 将软引用指向新的 war 包
  ls -l $serviceBasePath
  rm -f $HEAD
  ln -s $dstJarFullPath $HEAD
  ls -l $serviceBasePath

  # 停止原来的服务
  stop
  if [[ $? -ne 0 ]]; then
    echo "fail to stop"
  fi

  #方案一：将war包拷贝到webapps下
  # cp $dstJarFullPath $tomcat_webapps_dir
  #方案二：在webapps目录下建立指定项目的软连接执行HEAD
  #添加软连接指向war包的话tomcat不识别，应该将其解压  
  #  HEAD_${pom_artifactid}=${tomcat_webapps_dir}/HEAD_${pom_artifactid}
  
  #清空原映射目录
  rm -rf ${serviceBasePath}/tomcat_map/*
  #删掉原始软连接
  cd $tomcat_webapps_dir  
  rm -f ${pom_artifactid}
  #将最新的war包拷贝至tomcat目录并解压
  cp $dstJarFullPath ${serviceBasePath}/tomcat_map
  cd ${serviceBasePath}/tomcat_map
  jar -xf ${artifact_url}
  #删除映射目录下的war包
  rm -rf ${artifact_url}
  #设置软连接
  cd $tomcat_webapps_dir
  ln -s $serviceBasePath/tomcat_map ${pom_artifactid}
  # 启用新的服务
  start
  if [[ $? -ne 0 ]]; then
    echo "fail to start: $serviceName"
    return 1;
  fi

  #查看tomcat是否正确启动
  status
 
  return 0;
}

#查看tomcat的状态和启动情况
status() {
    echo "Statusing Tomcat"
    
    #进入到tomcat的日志目录
    cd $TOMCAT_BASE_DIR/logs
    #打印catalina.out日志的最后部分
    tail -10 catalina.out
    
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
	echo $"Usage: $0 {init|deploy|start|stop|restart|condrestart}"
	RETVAL=1
esac

# exit命令用于退出当前shell，在shell脚本中可以终止当前脚本执行。
exit $RETVAL 

