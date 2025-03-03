package com.unicam.rest;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.persistence.EntityManager;
import javax.persistence.EntityManagerFactory;
import javax.persistence.Persistence;
import javax.persistence.TypedQuery;
import javax.servlet.http.HttpSession;
import javax.transaction.TransactionManager;

import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

import com.unicam.model.*;
import org.glassfish.jersey.media.multipart.FormDataContentDisposition;
import org.glassfish.jersey.media.multipart.FormDataParam;
import com.mongodb.MongoWriteException;
import com.unicam.translator.OLD_Choreography;

@Path("/")
public class Controller {

	private User loggedUser;
	HttpSession session;

	// accessing JBoss's Transaction can be done differently but this one works
	// nicely
	TransactionManager tm = com.arjuna.ats.jta.TransactionManager.transactionManager();

	// build the EntityManagerFactory as you would build in in Hibernate ORM
	EntityManagerFactory emf = Persistence.createEntityManagerFactory("OGMPU");


	// now id is autoincremental, useless function.
	/*
	 * public int getLastId(String collection) { MongoCollection<Document> d =
	 * db.getCollection(collection);
	 * 
	 * FindIterable<Document> allElements = d.find(); int finalId = 0; if
	 * (allElements != null) { for (Document docUser : allElements) { finalId =
	 * docUser.getInteger("ID"); } }
	 *
	 * return finalId;
	 *
	 * }
	 */
	public String setOS(int a){
		String redirect = " ";
		String os = System.getProperty("os.name").toLowerCase();
		if (a == 1){//os.contains("win") || os.contains("osx")){
			redirect="http://virtualpros.unicam.it:8080/ChorChain/homePage.html";
			//redirect= "http://localhost:8080/ChorChain_war_exploded/homePage.html";
		} else if (a==2){//os.contains("nix") || os.contains("aix") || os.contains("nux")){
			redirect="http://virtualpros.unicam.it:8080/ChorChain/homePage.html";
		}else if (a==3){//os.contains("nix") || os.contains("aix") || os.contains("nux")){
			redirect="http://localhost:8081/ChorChain/homePage.html";
		}
		return redirect;
	}


	@POST
	@Path("reg/")
	public String sub(User user) throws Exception {
		String result;
		tm.begin();
		EntityManager em = emf.createEntityManager();
		
		try {
			em.persist(user);
			
			return "Registered";
		} catch (MongoWriteException e) {
			tm.rollback();
			if (e.getCode() == 11000) {
				return "Address already registered";
			} else
				return "Some error occurred";
		}
		finally {
			//System.out.println("finito reg");
			tm.commit();
			em.clear();
			em.close();
		}
		
	}

	@GET
	@Path("/sel/")
	@Produces(MediaType.TEXT_PLAIN)
	public void ret() throws Exception {
		tm.begin();
		EntityManager em = emf.createEntityManager();

		em.flush();
		em.close();
		tm.commit();
		emf.close();
		/*
		 * MongoCollection<Document> d = db.getCollection("files");
		 * MongoCollection<Document> Q = db.getCollection("Instances");
		 * MongoCollection<Document> W = db.getCollection("Models");
		 * MongoCollection<Document> zzz = db.getCollection("account");
		 * zzz.deleteMany(new Document()); d.deleteMany(new Document());
		 * W.deleteMany(new Document()); Q.deleteMany(new Document());
		 * FindIterable<Document> c = d.find(); for (Document document : c) {
		 * System.out.println(document); }
		 */
	}

	public User retrieveUser(String id) throws Exception {
		tm.begin();
		EntityManager em = emf.createEntityManager();
		try {
			User user = em.find(User.class, id);
			tm.commit();
			return user;
		}catch(Exception e) {
			tm.rollback();
			return null;
		}finally {
			em.clear();
			em.close();
		}
			
	}

	@POST
	@Path("/login/")
	public String login(User user) throws Exception {
		tm.begin();
		EntityManager em = emf.createEntityManager();
		
		TypedQuery<User> query = em.createNamedQuery("User.findByAddress", User.class);
		try {
			query.setParameter("address", user.getAddress());
			User loggedUser = query.getSingleResult();
			tm.commit();
			return loggedUser.getID();
		} catch (Exception nre) {
			tm.rollback();
			return null;
		}finally {
			em.clear();
			em.close();
		}
	}

	@POST
	@Path("/upload")
	public String upload(@FormDataParam("cookieId") String cookieId,
			@FormDataParam("fileName") InputStream uploadedInputStream,
			@FormDataParam("fileName") FormDataContentDisposition fileDetail) throws Exception {
		//tm.begin();

		try {
			loggedUser = retrieveUser(cookieId);
		} catch (Exception e1) {
			return null;
		}
		String filepath = ContractFunctions.projectPath + "/bpmn/" + fileDetail.getFileName();

		OutputStream outputStream = null;
		int read = 0;
		try {
			byte[] bytes = new byte[1024];
			File to = new File(filepath);
			//System.out.println(to.getPath());
			to.createNewFile();
			outputStream = new FileOutputStream(to);
			while ((read = uploadedInputStream.read(bytes)) != -1) {
				outputStream.write(bytes, 0, read);
			}
			outputStream.flush();
			outputStream.close();
		} catch (Exception e) {
			e.printStackTrace();
		}
		OLD_Choreography getRoles = new OLD_Choreography();
		getRoles.readFile(new File(filepath));
		getRoles.getParticipants();
		List<String> roles = OLD_Choreography.participantsWithoutDuplicates;
		Model modelUploaded = new Model(fileDetail.getFileName(), loggedUser.getAddress(), roles, new ArrayList<Instance>());
		tm.begin();
		EntityManager em = emf.createEntityManager();
		
		em.persist(modelUploaded);
		tm.commit();
		
		em.close();
		//em.flush();
		
		return "<meta http-equiv=\"refresh\" content=\"0; url="+ setOS(3) +"\">";
	}

	@POST
	@Path("/getModels")
	@Produces(MediaType.APPLICATION_JSON)
	public List<Model> getAll() throws Exception {
		List<Model> allModels = new ArrayList<Model>();
		tm.begin();
		EntityManager em = emf.createEntityManager();
		try {
			
			TypedQuery<Model> query = em.createNamedQuery("Model.findAll", Model.class);
			allModels = query.getResultList();
			tm.commit();
		}catch(Exception e) {
			tm.rollback();
		}finally {
			
			em.close();
		}
		return allModels;
		
	}
	
	@POST
	@Path("/createInstance/{cookieId}")
	public Instance createInstance(Map alldata, @PathParam("cookieId") String cookieId) throws Exception {
		
		String m = (String) alldata.get("modelID");
		List<String> visibleAt = (List<String>) alldata.get("visibleAt");
		List<String> mandatoryRoles = (List<String>) alldata.get("mandatory");
		List<String> optionalRoles = (List<String>) alldata.get("optional");
		String instanceId = "";
		tm.begin();
		EntityManager em = emf.createEntityManager();
		Instance modelInstance = new Instance();
		try {
			
			loggedUser = em.find(User.class, cookieId);
			
			//if visibleAt is null, it means that the instance is public, otherwise I need to insert also
			//the user address into the array
			if(visibleAt.get(0).equals("null")) {
				visibleAt = null;
			} else {
				visibleAt.add(loggedUser.getAddress());
			}
			
			if(optionalRoles.get(0).equals("null")) {
				optionalRoles = null;
			}
			
			Model model = em.find(Model.class, m);
			List<Instance> modelInstances = model.getInstances();
			ContractObject deployedContract = new ContractObject();
			int martsia = (int) (Math.random() * (1000000 - 1)) + 1;
			;
			//List<String> visibleAt = new ArrayList<String>();
			modelInstance = new Instance(model.getName(), 0, mandatoryRoles.size(), new HashMap<String, User>(), mandatoryRoles, optionalRoles,
					mandatoryRoles, optionalRoles, loggedUser.getAddress(), false,  visibleAt, deployedContract, martsia);

			modelInstances.add(modelInstance);
			model.setInstances(modelInstances);
			
			em.persist(deployedContract);
			em.persist(modelInstance);
			//instanceId =  modelInstance.getID();


			//List<Instance> userInstances = loggedUser.getInstances();
			//userInstances.add(modelInstance);
			//loggedUser.setInstances(userInstances);
			em.close();
			tm.commit();
		} catch (Exception e) {
			  tm.rollback();
			  e.printStackTrace();
		}

		return modelInstance;

		//tm.commit();
		//System.out.println("transaction after create inst" + tm.getTransaction());

	}

	@POST
	@Path("/getInstances/")
	public List<Instance> getAllInstances(Model m) throws Exception {
		List<Instance> allInstances = null;
		try {
			
			EntityManager em = emf.createEntityManager();
			Model model = em.find(Model.class, m.getID());
			//System.out.println(model.toString());
			allInstances = model.getInstances();

			//System.out.println(allInstances);
			em.close();
		} catch (Exception e) {
			e.printStackTrace();
		} 
		return allInstances;
	}

	@POST
	@Path("/getMartsiaInstance/")
	public MartsiaInstance getMartsiaInstance(String martsiaId) throws Exception {
		MartsiaInstance martsiaInstance = new MartsiaInstance();
		try {

			EntityManager em = emf.createEntityManager();
			martsiaInstance = em.find(MartsiaInstance.class, martsiaId);
			//System.out.println(model.toString());

			//System.out.println(allInstances);
			em.close();
		} catch (Exception e) {
			e.printStackTrace();
		}
		return martsiaInstance;
	}

	@POST
	@Path("/subscribe/{role}/{cookieId}/{instanceID}")
	public String subscribe(@PathParam("role") String role, @PathParam("cookieId") String cookieId,
			@PathParam("instanceID") String instanceId) throws Exception {

		tm.begin();
		EntityManager em = emf.createEntityManager();
		try {
			System.out.println("role:" + role);
			System.out.println("cookie:" + cookieId);
			System.out.println("instanceID:" + instanceId);
			loggedUser = em.find(User.class, cookieId);
			Instance instanceToSub = em.find(Instance.class, instanceId);
			int max = instanceToSub.getMaxNumber();
			int actual = instanceToSub.getActualNumber();
			if (max >= actual + 1) {
				instanceToSub.setActualNumber(actual + 1);
				List<String> freeRoles = instanceToSub.getFreeRoles();
				freeRoles.remove(role);
				Map<String, User> subscribers = instanceToSub.getParticipants();
				subscribers.put(role, loggedUser);
				em.merge(instanceToSub);

				List<Instance> userInstances = loggedUser.getInstances();
				userInstances.add(instanceToSub);
				loggedUser.setInstances(userInstances);
				tm.commit();
			}
			
		} catch (Exception e) {
			 tm.rollback();
			e.printStackTrace();
		} finally {
			em.close();
			
		}

		//tm.commit();
		//System.out.println("tm status after subscribe" + tm.getStatus());

		System.out.println(loggedUser);
		return "Subscribed successfully";

	}

	@POST
	@Path("generateMartsiaInstance/{cookieId}/{instanceID}")
	public MartsiaInstance getMartsiaInstance(@PathParam("cookieId") String cookieId,
								 @PathParam("instanceID") String instanceId) throws Exception {
		MartsiaInstance m = null;
		try {
			ContractFunctions contract = new ContractFunctions();
			EntityManager em = emf.createEntityManager();
			Instance instanceForDeploy = em.find(Instance.class, instanceId);
			ContractObject existingContractObject = instanceForDeploy.getDeployedContract();
			m = contract.createMartsiaData(existingContractObject, instanceForDeploy.getName(), instanceForDeploy.getParticipants(),
					instanceForDeploy.getOptionalRoles(), instanceForDeploy.getMandatoryRoles());
			existingContractObject.getTaskIdAndMartsiaId();
			tm.begin();
			EntityManager em2 = emf.createEntityManager();
			em2.merge(instanceForDeploy);
			em2.merge(existingContractObject);
			tm.commit();
			em2.close();
		}catch(Exception e){
			tm.rollback();
			e.printStackTrace();
		}finally {
			return m;	
		}
		 
	}



	@POST
	@Path("/deploy/{cookieId}/{instanceID}")
	public ContractObject deploy(@PathParam("cookieId") String cookieId,
			@PathParam("instanceID") String instanceId) throws Exception {
		ContractObject contractReturn = new ContractObject();
		//tm.begin();
		try {
			EntityManager em = emf.createEntityManager();
			loggedUser = em.find(User.class, cookieId);
			Instance instanceForDeploy = em.find(Instance.class, instanceId);
			em.close();
			String path = ContractFunctions.projectPath + File.separator + "resources" + File.separator;
			ContractFunctions contract = new ContractFunctions();
			contractReturn = instanceForDeploy.getDeployedContract();
			contractReturn = contract.createSolidity(instanceForDeploy.getName(), instanceForDeploy.getParticipants(),
					instanceForDeploy.getOptionalRoles(), instanceForDeploy.getMandatoryRoles());
			contract.compile(instanceForDeploy.getName());
			/*long startTime = System.nanoTime();
			String cAddress = contract.deploy(instanceForDeploy.getName());
			long endTime = System.nanoTime();
			long timeElapsed = endTime - startTime;
			System.out.println("Execution time in milliseconds: " + timeElapsed / 1000000);
			if(cAddress.equals("ERROR")) {
				//tm.rollback();
				return null;
			}
			contractReturn.setAddress(cAddress);*/
			/*contractReturn.setAbi(
					contract.readLineByLineJava8(path + contract.parseName(instanceForDeploy.getName(), ".abi"), false));
			contractReturn.setBin("0x"
					+ contract.readLineByLineJava8(path + contract.parseName(instanceForDeploy.getName(), ".bin"), true));*/
			instanceForDeploy.setDeployedContract(contractReturn);
			instanceForDeploy.setDone(true);
			
			tm.begin();
			EntityManager em2 = emf.createEntityManager();
			em2.persist(contractReturn);
			em2.merge(instanceForDeploy);
			tm.commit();
			em2.close();
		}catch(Exception e){
			tm.rollback();
			e.printStackTrace();
		}finally {
			return contractReturn;
		}
	}

	@POST
	@Path("/getCont/{cookieId}/")
	public List<Instance> getUserContracts(@PathParam("cookieId") String cookieId) {

		try {
			loggedUser = retrieveUser(cookieId);
			
		}
		catch(Exception e) {
			e.printStackTrace();
		}

		List<Instance> cList = new ArrayList<>();
		List<Instance> userInstances = loggedUser.getInstances();
		for(Instance i : userInstances) {
			if(i.isDone() == true) cList.add(i);
		}

		return cList;

	}
	
	@POST
	@Path("/getPart/{instanceId}/")
	public Map<String, String> getInstParticipants(@PathParam("instanceId") String instanceId) throws Exception {
		EntityManager em = emf.createEntityManager();
		Map<String, String> participants = new HashMap<String, String>();

		try {
			Instance inst = em.find(Instance.class, instanceId);
			Map<String,User> map = inst.getParticipants();
			for(Map.Entry<String, User> sub : map.entrySet()) {
				participants.put(sub.getKey(), sub.getValue().getID());
			}
			em.close();
		}
		catch(Exception e) {
			e.printStackTrace();
		} 
		return participants;
	}

	

	@POST
	@Path("/getUserInfo/{cookieId}")
	public User getUserInfo(@PathParam("cookieId") String cookieId) throws Exception {
		loggedUser = retrieveUser(cookieId);
		//System.out.println(loggedUser);
		return loggedUser;
	}


	
	@POST
	@Path("/saveModel/{fileName}/{cookieId}")
	public void saveModel(@PathParam("fileName") String filename, @PathParam("cookieId") String cookieId , String xml) throws Exception {

		tm.begin();
		EntityManager em = emf.createEntityManager();
		try {
			loggedUser = em.find(User.class, cookieId);
			filename = filename + ".bpmn";
			File uploaded = new File(ContractFunctions.projectPath +  File.separator + "bpmn"+  File.separator + filename);

			FileWriter wChor = new FileWriter(uploaded);

			BufferedWriter bChor = new BufferedWriter(wChor);
			bChor.write(xml);
			bChor.flush();
			bChor.close();

			OLD_Choreography getRoles = new OLD_Choreography();
			getRoles.readFile(uploaded);
			getRoles.getParticipants();
			List<String> roles = OLD_Choreography.participantsWithoutDuplicates;
			Model modelUploaded = new Model(filename, loggedUser.getAddress(), roles, new ArrayList<Instance>());
			em.persist(modelUploaded);
			tm.commit();
		}catch(Exception e) {
			e.printStackTrace();
			tm.rollback();
		}finally {
			em.close();
		}
	}
	
	@POST
	@Path("/getXml/{fileName}")
	public String getxml(@PathParam("fileName") String fileName) {
		String xml = "";
		try {
			xml = new String(Files.readAllBytes(Paths.get(ContractFunctions.projectPath + File.separator + "bpmn"+  File.separator + fileName)));
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
		return xml;
	}
	
	@GET
	@Path("/requestNewXml/")
	public String newXml() {
		String xml = "";
		try {
			xml = new String(Files.readAllBytes(Paths.get(ContractFunctions.projectPath + File.separator + "bpmn"+  File.separator + "newDiagram.bpmn")));
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}		
		return xml;
	}
	
	@GET
	@Path("/changeOptional/{role}/{instanceId}/{modelId}")
	public void changeOptionalRole(@PathParam("role") String optionalRole, @PathParam("instanceId") String instanceId, 
			 @PathParam("modelId") String modelId) throws Exception {
		tm.begin();
		EntityManager em = emf.createEntityManager();
		//System.out.println(optionalRole + instanceId);
		try {
			Instance actualInstance = em.find(Instance.class, instanceId);
			List<String> mandatory = actualInstance.getFreeRoles();
			mandatory.remove(optionalRole);
		
			List<String> optional = actualInstance.getFreeRolesOptional();
			optional.add(optionalRole);
			//Model actualModel = em.find(Model.class, modelId);
			actualInstance.setMaxNumber(mandatory.size());
			//em.merge(actualModel);
			em.merge(actualInstance);
			tm.commit();
		}catch(Exception e) {
			tm.rollback();
		}finally {
			em.close();
		}
	}
	
	@POST
	@Path("/getContractFromInstance/{instanceId}")
	public ContractObject getContractFromInstance(@PathParam("instanceId") String instanceId) {
		ContractObject contract = new ContractObject();
		EntityManager em = emf.createEntityManager();
		Instance instance = em.find(Instance.class, instanceId);
		try {
			contract = instance.getDeployedContract();
			em.close();
		}
		catch(Exception e) {
			
			e.printStackTrace();
		} 
		return contract;
		
	}
	
	@POST
	@Path("/newSubscribe/{instanceId}/{role}/{cookieId}")
	public void newSubscribe(@PathParam("instanceId") String instanceId, @PathParam("role") String role, 
			@PathParam("cookieId") String cookieId) throws Exception {
		tm.begin();
		EntityManager em = emf.createEntityManager();
		//loggedUser = retrieveUser(cookieId);
		loggedUser = em.find(User.class, cookieId);
		Instance instance = em.find(Instance.class, instanceId);
		try {
			List<String> optionalRoles = instance.getFreeRolesOptional();
			optionalRoles.remove(role);
			Map<String, User> subscribers = instance.getParticipants();
			subscribers.put(role, loggedUser);
            em.merge(instance);

            List<Instance> userInstances = loggedUser.getInstances();
            userInstances.add(instance);
            loggedUser.setInstances(userInstances);

			tm.commit();
		}catch(Exception e) {
			tm.rollback();
		}finally {
			em.close();
		}
	}
	
	@POST
	@Path("/external/contractFunction/{instanceId}/{account}/{functionName}")
	public void ExternalContractInteraction(@PathParam("instanceId") String instanceId, @PathParam("account") String account, 
			@PathParam("functionName") String functionName, Parameters parameters) throws Exception {
		ContractObject contract = new ContractObject();
		EntityManager em = emf.createEntityManager();
		Instance instance = em.find(Instance.class, instanceId);
		try {
			contract = instance.getDeployedContract();
		}catch(Exception e) {
			e.printStackTrace();
		}finally {
			em.close();
		}
		ContractFunctions con = new ContractFunctions();
		con.signOffline(parameters, contract, account, functionName);
	}

}
