const controller = require('../controllers/Controller');
const StudentController = new controller();
const express = require('express');
const router = express.Router();

router.get('/',StudentController.getAllStudents.bind(StudentController));
router.get('/view',StudentController.renderStudentsPage.bind(StudentController));
router.get('/:id',StudentController.getStudentById.bind(StudentController));
router.post('/',StudentController.createStudent.bind(StudentController));
router.put('/:id',StudentController.updateStudent.bind(StudentController));
router.delete('/:id',StudentController.deleteStudent.bind(StudentController));


module.exports = router;