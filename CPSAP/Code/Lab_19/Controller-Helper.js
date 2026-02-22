function MVCRouter(uri_templates){
    this.uri_templates = [...arguments];
}

function MVCControllers(controllers_map){
    this.controllers_map = controllers_map;
}

function MVC(router,controllers){
    this.router = router;
    this.controllers =controllers;
    this.use = (req,res,nex)=>{
        let controller = this.controllers.controllers_map[req.params.controller];
        if(controller){
            let action =controller[req.params.action];
            if(action){
                action(req,res,nex)
            }
            else{
                next();
            }
        }
        else{
            next();
        }
    }
}


exports.MVCRouter = MVCRouter;
exports.MVCControllers = MVCControllers;
exports.MVC = MVC;