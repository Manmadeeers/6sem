const StudentsController = require('../controllers/studentsController.js');
const controller = new StudentsController();
const express = require('express');
const router = express.Router();

router.get('/', controller.renderIndexPage.bind(controller));       
router.get('/list', controller.getAllStudents.bind(controller));   
router.get('/:id', controller.getStudentById.bind(controller));     
router.post('/', controller.createStudent.bind(controller));       
router.put('/:id', controller.updateStudent.bind(controller));     
router.delete('/:id', controller.deleteUser.bind(controller));     

module.exports = router;